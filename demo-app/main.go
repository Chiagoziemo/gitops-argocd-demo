// demo-app is a minimal HTTP service used to demonstrate Argo Rollouts canary
// analysis. Its only interesting behavior is FAILURE_RATE: the fraction of
// requests that deliberately return 500 and sleep past the latency SLO, so
// that a "bad" version can be rolled out on demand (see
// scripts/inject-failure.sh) and caught by the Prometheus AnalysisTemplates
// before it ever reaches 100% of traffic.
package main

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	requestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total HTTP requests, labeled by status code.",
	}, []string{"service", "code"})

	requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request duration in seconds.",
		Buckets: prometheus.DefBuckets,
	}, []string{"service"})
)

func main() {
	serviceName := getenv("SERVICE_NAME", "demo-app")
	version := getenv("VERSION", "dev")
	port := getenv("PORT", "8080")
	failureRate := getenvFloat("FAILURE_RATE", 0.0)

	log.Printf("starting %s version=%s port=%s failure_rate=%.2f", serviceName, version, port, failureRate)

	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		if rand.Float64() < failureRate {
			// Simulate a slow, failing backend call so both AnalysisTemplates
			// (success-rate and latency-p99) have something to catch.
			time.Sleep(400 * time.Millisecond)
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = fmt.Fprintf(w, "internal error from %s version=%s\n", serviceName, version)
			requestsTotal.WithLabelValues(serviceName, "500").Inc()
		} else {
			time.Sleep(time.Duration(rand.Intn(30)) * time.Millisecond)
			w.WriteHeader(http.StatusOK)
			_, _ = fmt.Fprintf(w, "hello from %s version=%s\n", serviceName, version)
			requestsTotal.WithLabelValues(serviceName, "200").Inc()
		}

		requestDuration.WithLabelValues(serviceName).Observe(time.Since(start).Seconds())
	})

	mux.Handle("/metrics", promhttp.Handler())

	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal(err)
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getenvFloat(key string, fallback float64) float64 {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return fallback
	}
	return f
}

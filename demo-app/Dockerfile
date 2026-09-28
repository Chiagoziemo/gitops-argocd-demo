FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN go mod tidy && CGO_ENABLED=0 go build -o /demo-app .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /demo-app /demo-app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/demo-app"]

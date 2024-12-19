FROM golang:1.23-alpine

WORKDIR /demo
RUN go install github.com/air-verse/air@latest
CMD ["air", "-d"]
FROM alpine:3.20
RUN apk add --no-cache curl coreutils
COPY load-generator/load-generator.sh /app/load-generator.sh
RUN chmod +x /app/load-generator.sh
ENTRYPOINT ["/app/load-generator.sh"]
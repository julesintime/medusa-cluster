FROM alpine:latest

RUN apk add --no-cache curl kubectl

COPY revised-admin-token.sh /usr/local/bin/revised-admin-token.sh

RUN chmod +x /usr/local/bin/revised-admin-token.sh

ENTRYPOINT ["/usr/local/bin/revised-admin-token.sh"]

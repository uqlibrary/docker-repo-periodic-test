FROM alpine:3.8

COPY repo-periodic-test.sh /root/repo-periodic-test.sh

RUN \
    # Upgrade
    apk upgrade --no-cache && \
    #
    # Required deps
    apk add --upgrade --no-cache bash git && \
    #
    # Remove apk cache
    rm -rf /var/cache/apk/*

ENTRYPOINT ["/root/repo-periodic-test.sh"]

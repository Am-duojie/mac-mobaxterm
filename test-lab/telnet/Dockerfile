FROM alpine:3.20

RUN apk add --no-cache busybox-extras

EXPOSE 23

CMD ["/usr/sbin/telnetd", "-F", "-l", "/bin/sh", "-p", "23"]

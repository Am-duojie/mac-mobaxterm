FROM alpine:3.20

RUN apk add --no-cache vsftpd shadow \
    && useradd -m -s /bin/sh tester \
    && echo "tester:password" | chpasswd \
    && mkdir -p /var/run/vsftpd /home/tester/upload \
    && chown -R tester:tester /home/tester

COPY vsftpd.conf /etc/vsftpd/vsftpd.conf

EXPOSE 21 21100-21110

CMD ["/usr/sbin/vsftpd", "/etc/vsftpd/vsftpd.conf"]

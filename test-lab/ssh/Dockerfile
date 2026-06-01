FROM alpine:3.20

RUN apk add --no-cache openssh shadow \
    && useradd -m -s /bin/sh tester \
    && echo "tester:password" | chpasswd \
    && ssh-keygen -A \
    && sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && printf '\nPort 2222\nX11Forwarding no\nAllowUsers tester\n' >> /etc/ssh/sshd_config \
    && mkdir -p /run/sshd

EXPOSE 2222

CMD ["/usr/sbin/sshd", "-D", "-e"]

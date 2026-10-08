FROM valkey/valkey:9.1.2

# Wings runs containers as its system user (default uid 988). Match it so the
# process has a passwd entry. Override with --build-arg if yours differs.
ARG CONTAINER_UID=988

USER root

# Wings drops capabilities from every container, and the kernel refuses to
# exec a binary whose file capabilities exceed the bounding set. Rewriting
# each file drops any security.capability xattr.
RUN find /usr/local/bin -type f -perm -u+x 2>/dev/null | while read -r f; do \
      cp "$f" "$f.nocap" && chmod --reference="$f" "$f.nocap" && mv -f "$f.nocap" "$f"; \
    done

RUN useradd -m -u ${CONTAINER_UID} -d /home/container -s /bin/bash container

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENV USER=container HOME=/home/container
USER container
WORKDIR /home/container

STOPSIGNAL SIGINT
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

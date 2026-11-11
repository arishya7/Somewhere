# The Somewhere online server: the game's relay running headless (no screens), for Render/Railway/Fly.
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget unzip libfontconfig1 \
	&& rm -rf /var/lib/apt/lists/*
ARG GODOT=4.7.2
RUN wget -q https://github.com/godotengine/godot/releases/download/${GODOT}-stable/Godot_v${GODOT}-stable_linux.x86_64.zip -O /tmp/godot.zip \
	&& unzip -q /tmp/godot.zip -d /opt && mv /opt/Godot_v${GODOT}-stable_linux.x86_64 /usr/local/bin/godot && rm /tmp/godot.zip
WORKDIR /app
COPY project.godot ./
COPY scenes ./scenes
COPY scripts ./scripts
RUN godot --headless --path /app --import || true
ENV PORT=9080
EXPOSE 9080
CMD ["sh", "-c", "godot --headless --path /app -- --relay"]

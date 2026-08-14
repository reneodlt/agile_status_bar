# Hosted pages

The support, privacy and copyright pages served at
<https://plunge.ragg.uk/octostatusbar/> — the URLs given to App Store Connect —
are **not** kept here. They live in the repository that owns that host:

    ~/code/plunge-predict/site/octostatusbar/

Deliberately one copy rather than two. They are baked into the
`registry.reneo.io/plunge-watch` image by `COPY . .`, so a copy in this repo
would be the one nobody deploys, and would quietly drift from what App Review
actually reads.

Laid out a directory per page (`support/index.html` and so on) so
`python -m http.server` resolves the extensionless URLs recorded in
[`../app-store-listing.md`](../app-store-listing.md). Links between the pages
are absolute for the same reason: the server 301s `/support` to `/support/`, and
relative links would resolve against the wrong base.

To change them, edit there and redeploy:

```sh
cd ~/code/plunge-predict
DOCKER_HOST=ssh://swarm102 docker build -t registry.reneo.io/plunge-watch:latest .
DOCKER_HOST=ssh://swarm102 docker push registry.reneo.io/plunge-watch:latest
source .mastodon.env && source .tunnel.env && \
  DOCKER_HOST=ssh://swarm102 docker stack deploy -c deploy/docker-stack.yml plunge
```

Build on the node, not locally: swarm102 is x86_64 and a Mac is arm64.

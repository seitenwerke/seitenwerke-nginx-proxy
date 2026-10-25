# Seitenwerke nginx-proxy fork

[![Docker Image Version (latest semver)](https://img.shields.io/docker/v/seitenwerke/nginx-proxy?label=docker%20version&sort=semver)](https://hub.docker.com/r/seitenwerke/nginx-proxy) ![Publish Docker image](https://github.com/seitenwerke/seitenwerke-nginx-proxy/actions/workflows/docker_push.yml/badge.svg?branch=master) ![Test](https://github.com/seitenwerke/seitenwerke-nginx-proxy/actions/workflows/test.yml/badge.svg?branch=master)

This is [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy) (based on upstream release `1.11.6`) with one addition: **automatic `www.` to non-`www.` redirects**.

### www redirect

Every `VIRTUAL_HOST` starting with `www.` answers every request with a `301` redirect to the same hostname without `www.`, keeping the request URI:

```yaml
environment:
  - VIRTUAL_HOST=example.com,www.example.com
  - LETSENCRYPT_HOST=example.com,www.example.com
```

- `http://www.example.com/foo` and `https://www.example.com/foo` both redirect to `https://example.com/foo` (a single hop).
- With `HTTPS_METHOD=nohttps` the target is `http://`, with `HTTPS_METHOD=noredirect` the request scheme is kept.
- Custom `HTTP_PORT` / `HTTPS_PORT` and the `com.github.nginx-proxy.nginx-proxy.non-get-redirect` label are honoured.
- Let's Encrypt HTTP-01 challenges (`/.well-known/acme-challenge/`) are still served locally on the `www.` host.
- Regexp and wildcard hostnames are never redirected.

To disable the redirect for the hosts of one container, set the label `com.github.nginx-proxy.nginx-proxy.www-redirect=false` on it. To disable it globally, set `WWW_REDIRECT=false` on the nginx-proxy container.

### Push a new version

To push a new version to Docker Hub, create a tag named after the bundled nginx version, e.g. `v1.31.3`. GitHub Actions builds the Debian based image and pushes it to [`seitenwerke/nginx-proxy`](https://hub.docker.com/r/seitenwerke/nginx-proxy). See `.github/workflows/docker_push.yml` for details.

### Updating from upstream

The whole fork is the template change in `nginx.tmpl` (search for `www_redirect`), its tests in `test/test_ssl/test_www-redirect.*` and the publishing workflow. To update, start a branch from the new upstream release and cherry-pick the fork commits on top of it.

# Original Readme

<a href="https://zerossl.com">
<picture>
  <!-- Dark mode -->
  <source
    media="(prefers-color-scheme: dark)"
    srcset="https://github.com/nginx-proxy/nginx-proxy/blob/main/docs/img/nginx-proxy_dark_theme.png" />
  <!-- Light mode -->
  <source
    media="(prefers-color-scheme: light)"
    srcset="https://github.com/nginx-proxy/nginx-proxy/blob/main/docs/img/nginx-proxy_light_theme.png" />
  <!-- Fallback for environments without media queries -->
  <img
    alt="ZeroSSL"
    src="https://github.com/nginx-proxy/nginx-proxy/blob/main/docs/img/nginx-proxy_light_theme.png"
    height="auto" />
</picture>
</a>

# nginx-proxy

[![Test](https://github.com/nginx-proxy/nginx-proxy/actions/workflows/test.yml/badge.svg)](https://github.com/nginx-proxy/nginx-proxy/actions/workflows/test.yml)
[![GitHub release](https://img.shields.io/github/v/release/nginx-proxy/nginx-proxy)](https://github.com/nginx-proxy/nginx-proxy/releases)
[![nginx 1.31.3](https://img.shields.io/badge/nginx-1.31.3-brightgreen.svg?logo=nginx)](https://nginx.org/en/CHANGES)
[![Docker Image Size](https://img.shields.io/docker/image-size/nginxproxy/nginx-proxy?sort=semver)](https://hub.docker.com/r/nginxproxy/nginx-proxy "Click to view the image on Docker Hub")
[![Docker stars](https://img.shields.io/docker/stars/nginxproxy/nginx-proxy.svg)](https://hub.docker.com/r/nginxproxy/nginx-proxy "DockerHub")
[![Docker pulls](https://img.shields.io/docker/pulls/nginxproxy/nginx-proxy.svg)](https://hub.docker.com/r/nginxproxy/nginx-proxy "DockerHub")

nginx-proxy sets up a container running nginx and [docker-gen](https://github.com/nginx-proxy/docker-gen). docker-gen generates reverse proxy configs for nginx and reloads nginx when containers are started and stopped.

See [Automated Nginx Reverse Proxy for Docker](http://jasonwilder.com/blog/2014/03/25/automated-nginx-reverse-proxy-for-docker/) for why you might want to use this.

### Usage

To run it:

```shell
docker run --detach \
    --name nginx-proxy \
    --publish 80:80 \
    --volume /var/run/docker.sock:/tmp/docker.sock:ro \
    nginxproxy/nginx-proxy:1.11
```

Then start any containers (here an nginx container) you want proxied with an env var `VIRTUAL_HOST=subdomain.yourdomain.com`

```shell
docker run --detach \
    --name your-proxied-app \
    --env VIRTUAL_HOST=foo.bar.com \
    nginx
```

Provided your DNS is setup to resolve `foo.bar.com` to the host running nginx-proxy, a request to `http://foo.bar.com` will then be routed to a container with the `VIRTUAL_HOST` env var set to `foo.bar.com` (in this case, the **your-proxied-app** container).

The containers being proxied must :

- [expose](https://docs.docker.com/engine/reference/run/#expose-incoming-ports) the port to be proxied, either by using the `EXPOSE` directive in their `Dockerfile` or by using the `--expose` flag to `docker run` or `docker create`.
- share at least one Docker network with the nginx-proxy container: by default, if you don't pass the `--net` flag when your nginx-proxy container is created, it will only be attached to the default bridge network. This means that it will not be able to connect to containers on networks other than bridge.

Note: providing a port number in `VIRTUAL_HOST` isn't suported, please see [virtual ports](https://github.com/nginx-proxy/nginx-proxy/tree/main/docs#virtual-ports) or [custom external HTTP/HTTPS ports](https://github.com/nginx-proxy/nginx-proxy/tree/main/docs#custom-external-httphttps-ports) depending on what you want to achieve.

### Image variants

The nginx-proxy images are available in two flavors.

#### Debian based version

This image is based on the nginx:mainline image, itself based on the debian slim image.

```shell
docker pull nginxproxy/nginx-proxy:1.11
```

#### Alpine based version (`-alpine` suffix)

This image is based on the nginx:alpine image.

```shell
docker pull nginxproxy/nginx-proxy:1.11-alpine
```

#### Dockergen version (`-dockergen` suffix)

This image is meant to be used in a [separate containers](https://github.com/nginx-proxy/nginx-proxy/blob/main/docs/README.md#separate-containers) setup with the official [nginx](https://registry.hub.docker.com/_/nginx/) image.

```shell
docker pull nginxproxy/nginx-proxy:1.11-dockergen
```

> [!IMPORTANT]
>
> #### A note on `latest`, `alpine` and `dockergen` tags:
>
> It is not recommended to use the `latest` (`nginxproxy/nginx-proxy`, `nginxproxy/nginx-proxy:latest`), `alpine` (`nginxproxy/nginx-proxy:alpine`) or `dockergen` (`nginxproxy/nginx-proxy:dockergen`) tag for production setups.
>
> [Those tags point](https://hub.docker.com/r/nginxproxy/nginx-proxy/tags) to the latest commit in the `main` branch. They do not carry any promise of stability, and using them will probably put your nginx-proxy setup at risk of experiencing uncontrolled updates to non backward compatible versions (or versions with breaking changes). You should always specify the version you want to use explicitly to ensure your setup doesn't break when the image is updated.

### Additional documentation

Please check the [docs section](https://github.com/nginx-proxy/nginx-proxy/tree/main/docs).

### Powered by 

[![GoLand logo](https://resources.jetbrains.com/storage/products/company/brand/logos/GoLand_icon.svg)](https://www.jetbrains.com/go/)
[![PyCharm logo](https://resources.jetbrains.com/storage/products/company/brand/logos/PyCharm_icon.svg)](https://www.jetbrains.com/pycharm/)

## About this repository
> [!NOTE]
> This repository is officially maintained by <strong>ZeroSSL</strong> as part of our commitment to secure and reliable SSL/TLS solutions.  
> We welcome contributions and feedback from the community!  
> For more information about our services, including free and paid SSL/TLS certificates, visit https://zerossl.com.
<p align="center">
	<a href="https://zerossl.com">
		<picture>
			<source media="(prefers-color-scheme: dark)" srcset="https://zerossl.com/assets/images/zerossl_logo_white.svg">
			<source media="(prefers-color-scheme: light)" srcset="https://zerossl.com/assets/images/zerossl_logo.svg">
			<img src="https://zerossl.com/assets/images/zerossl_logo.svg" alt="ZeroSSL" width="256">
		</picture>
	</a>
</p>

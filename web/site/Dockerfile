# Fokus destek sitesi. Coolify: Base Directory /web/site, Build Pack = Dockerfile, Port 80.
# Zorunlu build argümanı: SUPPORT_EMAIL (boşsa derleme kasıtlı olarak başarısız olur).

# 1) Derleme: __SUPPORT_EMAIL__ yer tutucusunu doldurur ve yayınlanacak dosyaları /out'a toplar.
FROM alpine:3.20 AS build
ARG SUPPORT_EMAIL
WORKDIR /src
COPY . .
RUN SUPPORT_EMAIL="${SUPPORT_EMAIL}" sh build.sh /out

# 2) Sunum: yalnızca statik dosyalar + nginx.
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY security-headers.conf /etc/nginx/fokus-security-headers.conf
COPY --from=build /out /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1

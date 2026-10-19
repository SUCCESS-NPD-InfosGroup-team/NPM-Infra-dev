# Dockerfile de Keycloak de produccion

# Extension que envia los correos por la API HTTP de Resend (Railway bloquea SMTP fuera de Pro)
FROM maven:3.9-eclipse-temurin-21 AS email
WORKDIR /src
COPY email-resend/pom.xml .
RUN mvn -q dependency:go-offline
COPY email-resend/src ./src
RUN mvn -q package

FROM quay.io/keycloak/keycloak:26.7.5 AS builder

ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true

COPY themes/ /opt/keycloak/themes
COPY --from=email /src/target/email-resend.jar /opt/keycloak/providers/
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.7.5
COPY --from=builder /opt/keycloak/ /opt/keycloak/
# Opcion de arranque (no de build): usa el provider "resend" en lugar del SMTP por defecto.
# Necesita la variable RESEND_API_KEY en el servicio
ENV KC_SPI_EMAIL_SENDER__PROVIDER=resend

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized"]

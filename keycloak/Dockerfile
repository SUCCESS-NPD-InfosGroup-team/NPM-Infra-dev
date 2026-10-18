# Dockerfile de Keycloak de produccion
FROM quay.io/keycloak/keycloak:26.7.5 AS builder

ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true

COPY themes/ /opt/keycloak/themes
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.7.5
COPY --from=builder /opt/keycloak/ /opt/keycloak/ 

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized"]
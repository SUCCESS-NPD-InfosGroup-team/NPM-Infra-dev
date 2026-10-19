package com.npd.keycloak.email;

import java.net.http.HttpClient;
import java.time.Duration;
import org.jboss.logging.Logger;
import org.keycloak.Config;
import org.keycloak.email.EmailSenderProvider;
import org.keycloak.email.EmailSenderProviderFactory;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;

/**
 * Registra el provider "resend". Se activa con KC_SPI_EMAIL_SENDER__PROVIDER=resend (ver keycloak/Dockerfile).
 * La API key se lee de la variable de entorno RESEND_API_KEY, así no queda guardada en la base de datos.
 */
public class ResendEmailSenderProviderFactory implements EmailSenderProviderFactory {

    public static final String PROVIDER_ID = "resend";

    private static final Logger LOG = Logger.getLogger(ResendEmailSenderProviderFactory.class);

    private HttpClient http;
    private String apiKey;

    @Override
    public void init(Config.Scope config) {
        apiKey = System.getenv("RESEND_API_KEY");
        http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    @Override
    public void postInit(KeycloakSessionFactory factory) {
        if (apiKey == null || apiKey.isBlank()) {
            LOG.warn("RESEND_API_KEY no está definida: los correos de Keycloak van a fallar");
        } else {
            LOG.info("Correos de Keycloak enviados por la API HTTP de Resend");
        }
    }

    @Override
    public EmailSenderProvider create(KeycloakSession session) {
        return new ResendEmailSenderProvider(http, apiKey);
    }

    @Override
    public String getId() {
        return PROVIDER_ID;
    }

    @Override
    public void close() {
    }
}

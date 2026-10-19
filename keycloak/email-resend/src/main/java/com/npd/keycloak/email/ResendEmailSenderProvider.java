package com.npd.keycloak.email;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.keycloak.email.EmailException;
import org.keycloak.email.EmailSenderProvider;

/**
 * Entrega los correos que arma Keycloak (plantillas, enlaces, idioma) con un POST a la API de Resend.
 * Los campos From / Reply-To salen de Realm settings → Email; host, puerto y contraseña se ignoran.
 */
public class ResendEmailSenderProvider implements EmailSenderProvider {

    private static final URI RESEND_URL = URI.create("https://api.resend.com/emails");
    private static final ObjectMapper JSON = new ObjectMapper();

    private final HttpClient http;
    private final String apiKey;

    public ResendEmailSenderProvider(HttpClient http, String apiKey) {
        this.http = http;
        this.apiKey = apiKey;
    }

    @Override
    public void send(Map<String, String> config, String address, String subject,
                     String textBody, String htmlBody) throws EmailException {
        if (apiKey == null || apiKey.isBlank()) {
            throw new EmailException("RESEND_API_KEY no está definida en el servicio de Keycloak");
        }
        validate(config);

        Map<String, Object> email = new HashMap<>();
        email.put("from", withDisplayName(config.get("from"), config.get("fromDisplayName")));
        email.put("to", List.of(address));
        email.put("subject", subject);
        if (htmlBody != null) {
            email.put("html", htmlBody);
        }
        if (textBody != null) {
            email.put("text", textBody);
        }
        String replyTo = config.get("replyTo");
        if (replyTo != null && !replyTo.isBlank()) {
            email.put("reply_to", withDisplayName(replyTo, config.get("replyToDisplayName")));
        }

        try {
            HttpRequest request = HttpRequest.newBuilder(RESEND_URL)
                    .timeout(Duration.ofSeconds(30))
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(JSON.writeValueAsString(email)))
                    .build();

            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 300) {
                // Resend explica el motivo en el cuerpo (dominio sin verificar, API key inválida, ...)
                throw new EmailException("Resend respondió " + response.statusCode() + ": " + response.body());
            }
        } catch (IOException e) {
            throw new EmailException("No se pudo contactar a Resend", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new EmailException("Envío a Resend interrumpido", e);
        }
    }

    @Override
    public void validate(Map<String, String> config) throws EmailException {
        String from = config.get("from");
        if (from == null || from.isBlank()) {
            throw new EmailException("Falta el remitente (From) en Realm settings → Email");
        }
    }

    @Override
    public void close() {
    }

    private static String withDisplayName(String address, String displayName) {
        if (displayName == null || displayName.isBlank()) {
            return address;
        }
        // Comillas para que una coma o un punto en el nombre no rompan la dirección
        return "\"" + displayName.replace("\"", "") + "\" <" + address + ">";
    }
}

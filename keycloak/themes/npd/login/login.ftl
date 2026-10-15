<#--
  Login form (Figma 18:180). Based on base/login/login.ftl from Keycloak 26.7.5.
  Without social providers and registration: the realm has neither, and the mockup's
  Google button is out of scope for now.
-->
<#import "template.ftl" as layout>
<#import "passkeys.ftl" as passkeys>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=true; section>
    <#if section = "header">
        ${msg("loginAccountTitle")}
    <#elseif section = "subtitle">
        <p class="npd-subtitle">${msg("npdSubtitle")}</p>
    <#elseif section = "form">
        <#if realm.password>
            <form id="kc-form-login" class="${properties.kcFormClass!}" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
                <#if !usernameHidden??>
                    <div class="${properties.kcFormGroupClass!}">
                        <label for="username" class="${properties.kcLabelClass!}"><#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if></label>
                        <input tabindex="1" id="username" class="${properties.kcInputClass!}" name="username" value="${(login.username!'')}" type="text"
                               placeholder="${msg("npdUsernamePlaceholder")}"
                               autofocus autocomplete="${(enableWebAuthnConditionalUI?has_content)?then('username webauthn', 'username')}"
                               aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                               <#if messagesPerField.existsError('username','password')>aria-describedby="input-error"</#if>
                               dir="ltr"
                        />
                    </div>
                </#if>

                <div class="${properties.kcFormGroupClass!}">
                    <label for="password" class="${properties.kcLabelClass!}">${msg("password")}</label>
                    <input tabindex="2" id="password" class="${properties.kcInputClass!}" name="password" type="password" autocomplete="current-password"
                           placeholder="${msg("npdPasswordPlaceholder")}"
                           aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                           <#if messagesPerField.existsError('username','password')>aria-describedby="input-error"</#if>
                    />
                    <#if messagesPerField.existsError('username','password')>
                        <span id="input-error" class="${properties.kcInputErrorMessageClass!}" aria-live="polite">
                            ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                        </span>
                    </#if>
                </div>

                <div class="${properties.kcFormSettingClass!}">
                    <#if realm.rememberMe && !usernameHidden??>
                        <label class="${properties.kcInputClassCheckbox!}">
                            <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox" class="${properties.kcInputClassCheckboxInput!}" <#if login.rememberMe??>checked</#if>>
                            <span class="${properties.kcInputClassCheckboxLabel!}">${msg("rememberMe")}</span>
                        </label>
                    <#else>
                        <span></span>
                    </#if>
                    <#if realm.resetPasswordAllowed>
                        <a tabindex="4" class="npd-link" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a>
                    </#if>
                </div>

                <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                <input tabindex="5" class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonBlockClass!} ${properties.kcButtonLargeClass!}" name="login" id="kc-login" type="submit" value="${msg("doLogIn")}"/>
            </form>
        </#if>
        <@passkeys.conditionalUIData />
    <#elseif section = "info">
        ${msg("npdNoAccess")}
    </#if>
</@layout.registrationLayout>

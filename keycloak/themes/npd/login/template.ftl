<#--
  NPD layout: brand side (Figma 18:151) + form side (18:179).
  Based on base/login/template.ftl from Keycloak 26.7.5: keep its scripts and nested
  sections ("header", "subtitle", "form", "socialProviders", "info", "show-username")
  so every login page still works with this layout.
-->
<#import "footer.ftl" as loginFooter>
<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html class="${properties.kcHtmlClass!}" lang="${lang}">

<head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <#if properties.meta?has_content>
        <#list properties.meta?split(' ') as meta>
            <meta name="${meta?split('==')[0]}" content="${meta?split('==')[1]}"/>
        </#list>
    </#if>
    <title>${msg("loginTitle", (realm.displayName!''))}</title>
    <link rel="icon" href="${url.resourcesPath}/img/favicon.svg" type="image/svg+xml" />
    <#if properties.styles?has_content>
        <#list properties.styles?split(' ') as style>
            <link href="${url.resourcesPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
    <#if properties.scripts?has_content>
        <#list properties.scripts?split(' ') as script>
            <script src="${url.resourcesPath}/${script}" type="text/javascript"></script>
        </#list>
    </#if>
    <script type="importmap">
        {
            "imports": {
                "rfc4648": "${url.resourcesCommonPath}/vendor/rfc4648/rfc4648.js"
            }
        }
    </script>
    <#if scripts??>
        <#list scripts as script>
            <script src="${script}" type="text/javascript"></script>
        </#list>
    </#if>
    <script type="module">
        <#outputformat "JavaScript">
        import { startSessionPolling } from ${(url.resourcesPath + "/js/authChecker.js")?c};

        startSessionPolling(
            ${url.ssoLoginInOtherTabsUrl?c}
        );
        </#outputformat>
    </script>
    <script type="module">
        document.addEventListener("click", (event) => {
            const link = event.target.closest("a[data-once-link]");
            if (!link) {
                return;
            }
            if (link.getAttribute("aria-disabled") === "true") {
                event.preventDefault();
                return;
            }
            const { disabledClass } = link.dataset;
            if (disabledClass) {
                link.classList.add(...disabledClass.trim().split(/\s+/));
            }
            link.setAttribute("role", "link");
            link.setAttribute("aria-disabled", "true");
        });
    </script>
    <#if authenticationSession??>
        <script type="module">
            <#outputformat "JavaScript">
            import { checkAuthSession } from ${(url.resourcesPath + "/js/authChecker.js")?c};

            checkAuthSession(
                ${authenticationSession.authSessionIdHash?c}
            );
            </#outputformat>
        </script>
    </#if>
</head>

<body class="${properties.kcBodyClass!} ${bodyClass}" data-page-id="login-${pageId}">
<div class="${properties.kcLoginClass!}">

    <aside class="npd-brand">
        <div class="npd-brand__top">
            <span class="npd-logo" aria-hidden="true">IG</span>
            <span class="npd-brand__name">${msg("npdBrandName")}</span>
        </div>
        <div class="npd-brand__spacer"></div>
        <p class="npd-brand__headline">${msg("npdHeadline1")}<br>${msg("npdHeadline2")}</p>
        <p class="npd-brand__tagline">${msg("npdTagline")}</p>
        <div class="npd-roster" aria-hidden="true">
            <span class="npd-roster__month" style="left: 6.41%">SEP</span>
            <span class="npd-roster__month" style="left: 20.96%">OCT</span>
            <span class="npd-roster__month" style="left: 35.51%">NOV</span>
            <span class="npd-roster__month" style="left: 50.07%">DIC</span>
            <span class="npd-roster__month" style="left: 64.62%">ENE</span>
            <span class="npd-roster__month" style="left: 79.17%">FEB</span>
            <span class="npd-roster__bar" style="left: 6.41%; width: 33.13%; top: 46px"></span>
            <span class="npd-roster__notice" style="left: 32.56%; top: 42px"></span>
            <span class="npd-roster__notice" style="left: 36.05%; top: 42px"></span>
            <span class="npd-roster__bar" style="left: 11.64%; width: 64.52%; top: 78px"></span>
            <span class="npd-roster__bar" style="left: 6.41%; width: 54.93%; top: 110px"></span>
            <span class="npd-roster__notice" style="left: 54.36%; top: 106px"></span>
            <span class="npd-roster__notice" style="left: 57.85%; top: 106px"></span>
            <span class="npd-roster__bar" style="left: 25.59%; width: 68%; top: 142px"></span>
            <span class="npd-roster__today" style="left: 24.72%"></span>
        </div>
        <div class="npd-brand__footer">
            <span>${msg("npdFooterOrg")}</span>
            <span>${msg("npdVersion")}</span>
        </div>
    </aside>

    <main class="npd-main">
        <div class="${properties.kcFormCardClass!}">
            <div class="npd-card__mobile-brand" aria-hidden="true">
                <span class="npd-logo npd-logo--inverse">IG</span>
                <span>${msg("npdBrandName")}</span>
            </div>

            <header class="${properties.kcFormHeaderClass!}">
                <#if !(auth?has_content && auth.showUsername() && !auth.showResetCredentials())>
                    <h1 id="kc-page-title" class="npd-title"><#nested "header"></h1>
                    <#nested "subtitle">
                <#else>
                    <#nested "show-username">
                    <div id="kc-username" class="npd-attempted">
                        <span id="kc-attempted-username">${auth.attemptedUsername}</span>
                        <a id="reset-login" class="npd-link" href="${url.loginRestartFlowUrl}">${msg("restartLoginTooltip")}</a>
                    </div>
                </#if>
                <#if displayRequiredFields>
                    <p class="${properties.kcContentWrapperClass!}"><span class="required">*</span> ${msg("requiredFields")}</p>
                </#if>
            </header>

            <#-- App-initiated actions should not see warning messages about the need to complete the action during login. -->
            <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
                <div class="${properties.kcAlertClass!} npd-alert--${message.type}" role="alert">
                    <span class="${properties.kcAlertTitleClass!}">${kcSanitize(message.summary)?no_esc}</span>
                </div>
            </#if>

            <#nested "form">

            <#if auth?has_content && auth.showTryAnotherWayLink()>
                <form id="kc-select-try-another-way-form" action="${url.loginAction}" method="post">
                    <input type="hidden" name="tryAnotherWay" value="on"/>
                    <a href="#" id="try-another-way" class="npd-link"
                       onclick="document.forms['kc-select-try-another-way-form'].requestSubmit();return false;">${msg("doTryAnotherWay")}</a>
                </form>
            </#if>

            <#nested "socialProviders">

            <#if displayInfo>
                <div id="kc-info" class="${properties.kcSignUpClass!}">
                    <div id="kc-info-wrapper" class="${properties.kcInfoAreaWrapperClass!}">
                        <#nested "info">
                    </div>
                </div>
            </#if>

            <@loginFooter.content/>
        </div>
    </main>
</div>
</body>
</html>
</#macro>

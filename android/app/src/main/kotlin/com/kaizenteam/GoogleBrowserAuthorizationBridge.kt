package com.kaizenteam

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.browser.auth.AuthTabIntent
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsService
import io.flutter.plugin.common.MethodChannel

/** Keeps browser OAuth results out of the website, including failed verification. */
class GoogleBrowserAuthorizationBridge(private val activity: Activity) {
    private data class PendingAuthorization(
        val id: String,
        val requestCode: Int,
        val callback: Uri,
        val result: MethodChannel.Result,
    )

    private var pending: PendingAuthorization? = null
    private var nextRequestCode = FIRST_REQUEST_CODE

    fun authorize(
        authorizationUrl: String?,
        redirectUri: String?,
        requestId: String?,
        result: MethodChannel.Result,
    ) {
        if (pending != null) {
            result.error("authorization_pending", "Google authorization is already open.", null)
            return
        }

        val url = authorizationUrl?.let(Uri::parse)
        val callback = redirectUri?.let(Uri::parse)
        if (url == null || callback == null || requestId.isNullOrBlank() ||
            url.scheme != "https" || url.host != "accounts.google.com" ||
            url.path != "/o/oauth2/v2/auth" || url.userInfo != null ||
            url.port !in listOf(-1, 443) ||
            callback.scheme != "https" || callback.host.isNullOrBlank() ||
            callback.userInfo != null || callback.port !in listOf(-1, 443) ||
            callback.query != null || callback.fragment != null ||
            url.getQueryParameters("redirect_uri") != listOf(redirectUri) ||
            url.getQueryParameters("state") != listOf(requestId)
        ) {
            result.error("invalid_request", "Invalid Google authorization configuration.", null)
            return
        }

        try {
            val browser = findAuthTabBrowser()
            if (browser == null) {
                // AuthTabIntent silently falls back to a normal Custom Tab on
                // older browsers. Do not launch that website fallback.
                result.error("unsupported_browser", "No browser supports Auth Tabs.", null)
                return
            }

            val requestCode = nextRequestCode
            nextRequestCode = if (requestCode == LAST_REQUEST_CODE) {
                FIRST_REQUEST_CODE
            } else {
                requestCode + 1
            }
            val intent = AuthTabIntent.Builder().build().intent.apply {
                data = url
                setPackage(browser)
                putExtra(AuthTabIntent.EXTRA_HTTPS_REDIRECT_HOST, callback.host)
                putExtra(AuthTabIntent.EXTRA_HTTPS_REDIRECT_PATH, callback.path)
            }
            pending = PendingAuthorization(requestId, requestCode, callback, result)
            // FlutterActivity uses Activity's result API. AuthTab's result
            // contract forwards this same intent and reads resultCode/data.
            activity.startActivityForResult(intent, requestCode)
        } catch (_: Exception) {
            pending = null
            result.error("browser_unavailable", "Could not open Google authorization.", null)
        }
    }

    fun cancel(requestId: String?) {
        val authorization = pending ?: return
        if (authorization.id != requestId) return
        pending = null
        activity.finishActivity(authorization.requestCode)
        authorization.result.success(null)
    }

    fun dispose() {
        cancel(pending?.id)
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode !in FIRST_REQUEST_CODE..LAST_REQUEST_CODE) return false
        val authorization = pending
        // Results from a dismissed attempt cannot finish its replacement.
        if (authorization == null || authorization.requestCode != requestCode) return true
        pending = null

        when (resultCode) {
            AuthTabIntent.RESULT_OK -> {
                val uri = data?.data
                val callback = authorization.callback
                if (uri == null || uri.scheme != callback.scheme ||
                    uri.host != callback.host || uri.path != callback.path ||
                    uri.port !in listOf(-1, 443) || uri.userInfo != null
                ) {
                    authorization.result.error(
                        "invalid_callback", "Google returned an invalid callback.", null,
                    )
                } else {
                    authorization.result.success(uri.toString())
                }
            }
            AuthTabIntent.RESULT_CANCELED -> authorization.result.success(null)
            AuthTabIntent.RESULT_VERIFICATION_FAILED -> authorization.result.error(
                "verification_failed", "The app and callback domain could not be verified.", null,
            )
            AuthTabIntent.RESULT_VERIFICATION_TIMED_OUT -> authorization.result.error(
                "verification_timed_out", "Callback verification timed out.", null,
            )
            else -> authorization.result.error(
                "authorization_failed", "Google authorization failed.", null,
            )
        }
        return true
    }

    private fun findAuthTabBrowser(): String? {
        val providers = activity.packageManager.queryIntentServices(
            Intent(CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION), 0,
        ).mapNotNull { it.serviceInfo?.packageName }.distinct()
        val preferred = CustomTabsClient.getPackageName(activity, providers.toMutableList())
        return (listOfNotNull(preferred) + providers).firstOrNull {
            CustomTabsClient.isAuthTabSupported(activity, it)
        }
    }

    private companion object {
        const val FIRST_REQUEST_CODE = 0x4700
        const val LAST_REQUEST_CODE = 0x47ff
    }
}

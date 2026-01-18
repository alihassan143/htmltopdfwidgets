package com.example.native_pdf_engine

import android.app.Activity
import android.graphics.pdf.PdfDocument
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import java.io.File
import java.io.FileOutputStream

class PdfGenerator(private val activity: Activity) {
    interface Callback {
        fun onSuccess()
        fun onFailure(message: String)
    }

    fun convert(content: String, isUrl: Boolean, path: String, callback: Callback) {
        activity.runOnUiThread {
            try {
                val webView = WebView(activity)
                webView.settings.javaScriptEnabled = true
                
                // Add to view hierarchy but hidden, to ensure layout/drawing works
                // Using 1x1 pixel or alpha 0
                val params = ViewGroup.LayoutParams(1024, 768) // Force specific size? Or match parent?
                // If we want PDF to be 1024px wide.
                // Actually printed PDF size depends on content.
                // Let's set a distinct width.
                // Note: WebView needs to be layouted.
                
                // We add it to the root view of the activity?
                // This might be intrusive.
                // Alternative: manually measure and layout.
                // webView.measure(widthSpec, heightSpec)
                // webView.layout(0, 0, width, height)
                // But loading might resize it?
                
                webView.webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView, url: String) {
                        // Delay slightly to ensure rendering?
                        view.postDelayed({
                            generate(view, path, callback)
                            // Cleanup
                            (view.parent as? ViewGroup)?.removeView(view)
                            view.destroy()
                        }, 500)
                    }
                    
                    override fun onReceivedError(view: WebView, errorCode: Int, description: String, failingUrl: String) {
                         callback.onFailure("WebView Error: \$description")
                         (view.parent as? ViewGroup)?.removeView(view)
                         view.destroy()
                    }
                }
                
                activity.addContentView(webView, ViewGroup.LayoutParams(1024, ViewGroup.LayoutParams.WRAP_CONTENT))
                // Hide it
                webView.visibility = View.INVISIBLE

                if (isUrl) {
                    webView.loadUrl(content)
                } else {
                    webView.loadDataWithBaseURL(null, content, "text/html", "UTF-8", null)
                }
            } catch (e: Exception) {
                callback.onFailure(e.toString())
            }
        }
    }

    private fun generate(webView: WebView, path: String, callback: Callback) {
        val document = PdfDocument()
        
        // Use webview content width/height
        val width = webView.width
        val height = (webView.contentHeight * webView.scale).toInt()

        if (width <= 0 || height <= 0) {
            callback.onFailure("Invalid WebView dimensions: width=\$width, height=\$height")
            return
        }

        val pageInfo = PdfDocument.PageInfo.Builder(width, height, 1).create()
        val page = document.startPage(pageInfo)
        
        webView.draw(page.canvas)
        document.finishPage(page)
        
        try {
            val file = File(path)
            val stream = FileOutputStream(file)
            document.writeTo(stream)
            stream.close()
            callback.onSuccess()
        } catch (e: Exception) {
            callback.onFailure(e.toString())
        } finally {
            document.close()
        }
    }
}

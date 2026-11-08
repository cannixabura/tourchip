package com.softchip.tourchip

import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.nl.languageid.LanguageIdentificationOptions
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 聊天與心情翻譯（Dart 端 tourchip/translate）：Google ML Kit，完全在手機上進行。
 * iPhone 用 Apple 翻譯（見 AppDelegate.swift），兩邊的方法名稱相同。
 */
class ChatTranslatorChannel(messenger: BinaryMessenger) {
    private val identifier = LanguageIdentification.getClient(
        LanguageIdentificationOptions.Builder().setConfidenceThreshold(0.5f).build())
    private val models = RemoteModelManager.getInstance()
    private val translators = mutableMapOf<String, Translator>()

    init {
        MethodChannel(messenger, "tourchip/translate").setMethodCallHandler { call, result ->
            when (call.method) {
                "identify" -> identifier.identifyLanguage(call.argument<String>("text") ?: "")
                    .addOnSuccessListener { result.success(it) }
                    .addOnFailureListener { result.success("und") }
                "supported" -> result.success(TranslateLanguage.fromLanguageTag(call.argument<String>("lang") ?: "") != null)
                "isDownloaded" -> models.isModelDownloaded(model(call.argument("lang")))
                    .addOnSuccessListener { result.success(it) }
                    .addOnFailureListener { result.success(false) }
                "download" -> models.download(model(call.argument("lang")), DownloadConditions.Builder().build())
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { result.success(false) }
                "translate" -> {
                    val source = call.argument<String>("source") ?: ""
                    val target = call.argument<String>("target") ?: ""
                    val translator = translators.getOrPut("$source>$target") {
                        Translation.getClient(TranslatorOptions.Builder().setSourceLanguage(source).setTargetLanguage(target).build())
                    }
                    translator.translate(call.argument<String>("text") ?: "")
                        .addOnSuccessListener { result.success(it) }
                        .addOnFailureListener { result.error("translate", it.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun model(lang: String?) = TranslateRemoteModel.Builder(lang ?: "").build()
}

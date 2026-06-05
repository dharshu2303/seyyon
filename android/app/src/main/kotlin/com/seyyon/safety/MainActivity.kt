package com.seyyon.safety

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.sosapp/sms"
    private val SPEECH_CHANNEL = "com.sosapp/speech"
    private val CALL_CHANNEL = "com.sosapp/call"
    
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var triggerPhrase = "help me"
    private var speechMethodChannel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // SMS Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSMS") {
                val phoneNumber = call.argument<String>("phone")
                val message = call.argument<String>("message")
                
                if (phoneNumber != null && message != null) {
                    try {
                        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }
                        val parts = smsManager.divideMessage(message)
                        if (parts.size > 1) {
                            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                        } else {
                            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                        }
                        result.success("SMS sent successfully")
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // Speech Recognition Channel
        speechMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
        speechMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    triggerPhrase = (call.argument<String>("triggerPhrase") ?: "help me").lowercase()
                    startSpeechRecognition()
                    result.success(true)
                }
                "stopListening" -> {
                    stopSpeechRecognition()
                    result.success(true)
                }
                "isListening" -> result.success(isListening)
                else -> result.notImplemented()
            }
        }
        
        // Call Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "makeCall") {
                val phoneNumber = call.argument<String>("phone")
                
                if (phoneNumber != null) {
                    try {
                        val callIntent = Intent(Intent.ACTION_CALL).apply {
                            data = Uri.parse("tel:$phoneNumber")
                        }
                        startActivity(callIntent)
                        result.success("Call initiated to $phoneNumber")
                    } catch (e: Exception) {
                        result.error("CALL_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Phone number is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startSpeechRecognition() {
        if (isListening) return
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            handler.post { speechMethodChannel?.invokeMethod("onError", "Not available") }
            return
        }
        
        isListening = true
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() { if (isListening) handler.postDelayed({ startIntent() }, 500) }
            override fun onError(error: Int) { if (isListening) handler.postDelayed({ startIntent() }, 1000) }
            override fun onResults(results: Bundle?) {
                processResults(results)
                if (isListening) handler.postDelayed({ startIntent() }, 300)
            }
            override fun onPartialResults(partial: Bundle?) { processResults(partial) }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        
        startIntent()
        handler.post { speechMethodChannel?.invokeMethod("onListening", true) }
    }

    private fun processResults(results: Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (!matches.isNullOrEmpty()) {
            val text = matches[0].lowercase()
            handler.post { speechMethodChannel?.invokeMethod("onResult", text) }
            if (text.contains(triggerPhrase)) {
                handler.post { speechMethodChannel?.invokeMethod("onTriggerDetected", triggerPhrase) }
            }
        }
    }

    private fun startIntent() {
        try {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) { }
    }

    private fun stopSpeechRecognition() {
        isListening = false
        try { speechRecognizer?.stopListening(); speechRecognizer?.destroy() } catch (e: Exception) { }
        speechRecognizer = null
        handler.post { speechMethodChannel?.invokeMethod("onListening", false) }
    }

    override fun onDestroy() { stopSpeechRecognition(); super.onDestroy() }
}

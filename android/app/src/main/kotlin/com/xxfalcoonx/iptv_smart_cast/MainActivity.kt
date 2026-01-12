package com.xxfalcoonx.iptv_smart_cast

import android.app.AlertDialog
import android.content.Context
import android.text.InputType
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // Canal de comunicação (deve ser igual ao definido no Dart)
    private val CHANNEL = "com.xxfalcoonx.iptv_smart_cast/tv_input"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "showNativeInput") {
                // Recebe os parâmetros do Flutter
                val label = call.argument<String>("label") ?: "Digitar"
                val initialValue = call.argument<String>("initialValue") ?: ""
                val isPassword = call.argument<Boolean>("isPassword") ?: false
                
                // Abre o input nativo
                showNativeInputDialog(label, initialValue, isPassword, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun showNativeInputDialog(label: String, initialValue: String, isPassword: Boolean, result: MethodChannel.Result) {
        val input = EditText(this)
        input.setText(initialValue)
        
        // Configura se é senha ou texto normal
        if (isPassword) {
            input.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        } else {
            input.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
        }

        val builder = AlertDialog.Builder(this)
        builder.setTitle(label)
        builder.setView(input)
        
        // Botão OK retorna o texto digitado para o Flutter
        builder.setPositiveButton("OK") { _, _ ->
            result.success(input.text.toString())
        }
        
        // Botão Cancelar
        builder.setNegativeButton("Cancelar") { dialog, _ ->
            dialog.cancel()
            result.success(null)
        }

        val dialog = builder.create()
        dialog.show()
        
        // Truque para forçar o teclado a aparecer na TV
        input.requestFocus()
        input.postDelayed({
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
        }, 200)
    }
}
package io.github.therealbiebs.ididthedishes;

import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.nfc.NdefMessage;
import android.nfc.NdefRecord;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.nfc.tech.Ndef;
import android.nfc.tech.NdefFormatable;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** NFC is foreground-only; the OS handles launching us from URL stickers. */
@CapacitorPlugin(name = "DishesNative")
public class DishesNativePlugin extends Plugin implements NfcAdapter.ReaderCallback {
    private NfcAdapter adapter;
    private PluginCall pendingWrite;
    private SharedPreferences storage;
    private static final String KEY_ALIAS = "dishes-session-v1";

    @Override public void load() {
        adapter = NfcAdapter.getDefaultAdapter(getContext());
        storage = getContext().getSharedPreferences("secure-session", 0);
        enableReader();
        readIntent(getActivity().getIntent());
    }
    private void enableReader() {
        getActivity().runOnUiThread(() -> {
            if (adapter != null && adapter.isEnabled()) adapter.enableReaderMode(getActivity(), this,
                NfcAdapter.FLAG_READER_NFC_A | NfcAdapter.FLAG_READER_NFC_B |
                NfcAdapter.FLAG_READER_NFC_F | NfcAdapter.FLAG_READER_NFC_V, null);
        });
    }
    @Override protected void handleOnResume() { enableReader(); }
    @Override protected void handleOnPause() {
        if (adapter != null) getActivity().runOnUiThread(() -> adapter.disableReaderMode(getActivity()));
        cancelPending("Writing cancelled because the app was closed.");
    }
    @Override protected void handleOnNewIntent(Intent intent) { readIntent(intent); }
    private void readIntent(Intent intent) {
        if (intent == null) return;
        Uri uri = intent.getData();
        if (validSticker(uri)) emit(uri.toString());
    }
    private boolean validSticker(Uri uri) {
        return uri != null && "https".equals(uri.getScheme()) &&
            "therealbiebs.github.io".equals(uri.getHost()) && uri.getPort() == -1 &&
            "/IDidTheDishes/".equals(uri.getPath()) &&
            uri.getQueryParameter("tag") != null && uri.getQueryParameter("tag").matches(
                "(?i)[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}");
    }
    private void emit(String url) { notifyListeners("tagScanned", new JSObject().put("url", url), true); }
    private boolean ready(PluginCall call) {
        if (adapter == null) { call.reject("This phone has no NFC reader."); return false; }
        if (!adapter.isEnabled()) { call.reject("Turn on NFC in your phone settings, then try again."); return false; }
        enableReader(); return true;
    }
    @PluginMethod public void checkNfc(PluginCall call) { if (ready(call)) call.resolve(); }
    @PluginMethod public synchronized void writeTag(PluginCall call) {
        if (!ready(call)) return;
        if (!validSticker(Uri.parse(call.getString("url", "")))) { call.reject("Invalid chore sticker link."); return; }
        if (pendingWrite != null) { call.reject("A sticker write is already waiting."); return; }
        pendingWrite = call;
    }
    private synchronized void cancelPending(String reason) {
        if (pendingWrite != null) { pendingWrite.reject(reason); pendingWrite = null; }
    }
    @PluginMethod public void cancelWrite(PluginCall call) { cancelPending("Writing cancelled."); call.resolve(); }
    @Override public void onTagDiscovered(Tag tag) {
        PluginCall write;
        synchronized (this) { write = pendingWrite; pendingWrite = null; }
        if (write != null) {
            try {
                NdefMessage message = new NdefMessage(new NdefRecord[]{NdefRecord.createUri(write.getString("url"))});
                Ndef ndef = Ndef.get(tag);
                if (ndef != null) {
                    try {
                        ndef.connect();
                        if (!ndef.isWritable()) throw new Exception("This sticker is read-only.");
                        if (ndef.getMaxSize() < message.toByteArray().length) throw new Exception("This sticker is too small for the link.");
                        ndef.writeNdefMessage(message);
                    } finally { ndef.close(); }
                } else {
                    NdefFormatable blank = NdefFormatable.get(tag);
                    if (blank == null) throw new Exception("This sticker does not support NDEF links.");
                    try { blank.connect(); blank.format(message); } finally { blank.close(); }
                }
                write.resolve();
            } catch (Exception e) { write.reject("Could not write sticker: " + e.getMessage()); }
            return;
        }
        Ndef ndef = Ndef.get(tag);
        if (ndef == null) return;
        try {
            ndef.connect(); NdefMessage message = ndef.getNdefMessage();
            if (message == null) return;
            for (NdefRecord record : message.getRecords()) {
                Uri uri = record.toUri();
                if (validSticker(uri)) { emit(uri.toString()); return; }
            }
        } catch (Exception e) {
            notifyListeners("scanError", new JSObject().put("message", "Could not read sticker. Hold your phone still and try again."));
        } finally { try { ndef.close(); } catch (Exception ignored) {} }
    }

    private synchronized SecretKey secretKey() throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore"); store.load(null);
        if (store.containsAlias(KEY_ALIAS)) return (SecretKey) store.getKey(KEY_ALIAS, null);
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return generator.generateKey();
    }
    @PluginMethod public void getSecure(PluginCall call) {
        String key = call.getString("key");
        if (key == null) { call.reject("Missing storage key."); return; }
        try {
            String saved = storage.getString(key, null);
            if (saved == null) { call.resolve(new JSObject()); return; }
            String[] parts = saved.split(":", 2);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), new GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)));
            String value = new String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), StandardCharsets.UTF_8);
            call.resolve(new JSObject().put("value", value));
        } catch (Exception e) {
            // A lost/invalidated Android key requires signing in again.
            storage.edit().remove(key).commit(); call.resolve(new JSObject());
        }
    }
    @PluginMethod public void setSecure(PluginCall call) {
        String key = call.getString("key"), value = call.getString("value");
        if (key == null || value == null) { call.reject("Missing storage value."); return; }
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE, secretKey());
            String saved = Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP) + ":" +
                Base64.encodeToString(cipher.doFinal(value.getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
            if (!storage.edit().putString(key, saved).commit()) throw new Exception("Storage full");
            call.resolve();
        } catch (Exception e) { call.reject("Could not save sign-in securely."); }
    }
    @PluginMethod public void removeSecure(PluginCall call) {
        String key = call.getString("key");
        if (key == null) { call.reject("Missing storage key."); return; }
        if (storage.edit().remove(key).commit()) call.resolve(); else call.reject("Could not clear sign-in.");
    }
}

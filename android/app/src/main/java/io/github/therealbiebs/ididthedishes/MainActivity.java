package io.github.therealbiebs.ididthedishes;

import com.getcapacitor.BridgeActivity;
import android.os.Bundle;

public class MainActivity extends BridgeActivity {
    @Override public void onCreate(Bundle state) {
        registerPlugin(DishesNativePlugin.class);
        super.onCreate(state);
    }
}

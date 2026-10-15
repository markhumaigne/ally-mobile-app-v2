package ph.humain.ally_mobile_app

import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun popSystemNavigator(): Boolean {
        // SystemNavigator.pop (Exit) must finish ALLY's task, including its
        // Recents entry, instead of falling back to Android back navigation.
        finishAndRemoveTask()
        return true
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // The launch theme suppresses Android's separate preview. Once Flutter
            // draws, make the activity opaque so Android can release the surface behind it.
            setTranslucent(false)
        }
    }
}

package com.chandrika.bloom.tests;

import com.android.uiautomator.core.UiObject;
import com.android.uiautomator.core.UiSelector;
import com.android.uiautomator.testrunner.UiAutomatorTestCase;

/** Runs in UI Automator's separate shell process; Bloom can stay terminated
 * until SystemUI sends the notification PendingIntent after this real tap. */
@SuppressWarnings("deprecation")
public class NotificationTapTest extends UiAutomatorTestCase {
    public void testTapNotification() throws Exception {
        getUiDevice().wakeUp();
        assertTrue("Notification drawer did not open", getUiDevice().openNotification());
        UiObject notification = new UiObject(new UiSelector().text("Cold launch test " + getParams().getString("id")));
        assertTrue("Test notification not visible", notification.waitForExists(10000));
        assertTrue("Notification tap failed", notification.click());
    }
}

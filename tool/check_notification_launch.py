#!/usr/bin/env python3
"""Verify actual posted notification PendingIntents after process death.

Builds/uses only com.chandrika.bloom.integration. Requires Flutter, adb, and
ANDROID_HOME. Does not read, stop, uninstall, or write the normal Bloom app.
"""
import json
import os
from pathlib import Path
import subprocess
import time
import tempfile

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = 'com.chandrika.bloom.integration'
DEVICE = os.environ.get('BLOOM_TEST_DEVICE', 'emulator-5554')


def run(*args, check=True):
    return subprocess.run(args, cwd=ROOT, check=check, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def adb(*args, check=True):
    return run('adb', '-s', DEVICE, *args, check=check)


def wait_result(checks, details, old_pid=None):
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline:
        result = adb('shell', 'run-as', PACKAGE, 'cat',
                     'cache/cold-launch-result.json', check=False)
        try:
            value = json.loads(result.stdout)
            if (value['checks'] == checks and value['details'] == details
                    and value['pid'] != old_pid):
                assert value['records'] == 0 and value['unchanged'], value
                return value
        except (ValueError, KeyError):
            pass
        time.sleep(0.25)
    raise AssertionError(f'Expected checks={checks}, details={details}; last={result.stdout}')


def main():
    env = dict(os.environ, ORG_GRADLE_PROJECT_bloomIntegrationTest='true')
    subprocess.run(['flutter', 'build', 'apk', '--debug', '--target',
                    'integration_test/notification_launch_app.dart'], cwd=ROOT, env=env, check=True)
    apk = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
    sdk = Path(os.environ['ANDROID_HOME'])
    aapt = sorted((sdk / 'build-tools').glob('*/aapt'))[-1]
    badging = run(str(aapt), 'dump', 'badging', str(apk)).stdout
    assert f"package: name='{PACKAGE}'" in badging, 'Refusing non-isolated APK'
    # Build a dependency-free UI Automator test with the installed SDK. It runs
    # in a separate shell process, so it does not pre-start Bloom's process.
    platform = sdk / 'platforms/android-36'
    junit = sorted((Path.home() / '.gradle/caches/modules-2/files-2.1/junit/junit').glob('*/*/junit-*.jar'))[-1]
    with tempfile.TemporaryDirectory(prefix='bloom-notification-tap-') as temp:
        temp = Path(temp)
        classes = temp / 'classes'
        dex = temp / 'dex'
        classes.mkdir()
        dex.mkdir()
        classpath = os.pathsep.join(map(str, [platform / 'android.jar', platform / 'uiautomator.jar', junit]))
        run('javac', '-source', '8', '-target', '8', '-cp', classpath, '-d', str(classes), str(ROOT / 'tool/android/NotificationTapTest.java'))
        run('jar', 'cf', str(temp / 'classes.jar'), '-C', str(classes), '.')
        run(str(aapt.parent / 'd8'), '--lib', str(platform / 'android.jar'), '--output', str(dex), str(temp / 'classes.jar'))
        run('jar', 'cf', str(temp / 'tap.jar'), '-C', str(dex), 'classes.dex')
        adb('push', str(temp / 'tap.jar'), '/data/local/tmp/bloom-notification-tap.jar')
    adb('install', '-r', '-g', str(apk))
    for notification_id, checks, details in [(441, 1, 0), (442, 0, 1), (443, 0, 0), (444, 0, 0)]:
        adb('shell', 'am', 'force-stop', PACKAGE)
        adb('shell', 'run-as', PACKAGE, 'sh', '-c', f"'echo {notification_id} > cache/cold-notification-id'")
        adb('shell', 'run-as', PACKAGE, 'rm', '-f', 'cache/cold-launch-result.json')
        adb('shell', 'am', 'start', '-W', '-n', f'{PACKAGE}/com.chandrika.bloom.IntegrationActivity')
        previous = wait_result(0, 0)
        adb('shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.HOME')
        deadline = time.monotonic() + 15
        while True:
            adb('shell', 'am', 'kill', PACKAGE)
            time.sleep(0.25)
            if not adb('shell', 'pidof', PACKAGE, check=False).stdout.strip():
                break
            assert time.monotonic() < deadline, 'Isolated fixture did not stop'
        adb('shell', 'run-as', PACKAGE, 'rm', '-f', 'cache/cold-launch-result.json')
        result = adb('shell', 'uiautomator', 'runtest', '/data/local/tmp/bloom-notification-tap.jar',
                     '-c', 'com.chandrika.bloom.tests.NotificationTapTest', '-e', 'id', str(notification_id), '-s')
        assert 'OK (1 test)' in result.stdout and 'aborted' not in result.stdout and 'shortMsg' not in result.stdout, result.stdout + result.stderr
        result = wait_result(checks, details, old_pid=previous['pid'])
        print(f'PASS cold drawer tap {notification_id}: checks={checks}, details={details}; no garden changes', flush=True)
    print('All four native cold-launch cases passed.', flush=True)


if __name__ == '__main__':
    main()

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ads.dart';
import '../app.dart';
import 'home.dart' show formatAdFreeUntil;

/// Keep in step with `version:` in pubspec.yaml (a test checks this).
const appVersion = '1.1.0';

const privacyUrl = 'https://tools.homilabs.org/privacy.html#beam';
const termsUrl = 'https://tools.homilabs.org/terms.html#beam';
const contactEmail = 'homilabs.smc@gmail.com';
const communityUrl = 'https://www.facebook.com/groups/2834353386950005?ref=app';

/// Opens [url] in the browser. Beam itself has no internet permission;
/// the browser does the fetching.
Future<void> openLink(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}

Future<void> showAboutSheet(BuildContext context, Ads ads) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  backgroundColor: const Color(0xFF15181D),
  builder: (ctx) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.flashlight_on, color: beamAmber),
              title: Text('Beam', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              subtitle: Text('Version $appVersion · by HomiLabs'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                ads.enabled
                    ? 'No account needed and your settings stay on this phone. Beam is free and shows '
                          'ads from Google AdMob; the privacy policy explains what they use.'
                    : 'No account needed. Your settings stay on this phone.',
                key: const Key('about-blurb'),
                style: const TextStyle(color: Colors.white60),
              ),
            ),
            ListenableBuilder(
              listenable: ads,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ads.isAdFree)
                    ListTile(
                      key: const Key('about-ad-free'),
                      leading: const Icon(Icons.block, color: beamAmber),
                      title: const Text('Ad-free'),
                      subtitle: Text('Until ${formatAdFreeUntil(ads.adFreeUntil)}'),
                    ),
                  if (ads.privacyOptionsRequired)
                    ListTile(
                      key: const Key('about-ad-privacy'),
                      leading: const Icon(Icons.tune),
                      title: const Text('Ad privacy choices'),
                      onTap: ads.showPrivacyOptions,
                    ),
                ],
              ),
            ),
            ListTile(
              key: const Key('about-privacy'),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy policy'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openLink(ctx, privacyUrl),
            ),
            ListTile(
              key: const Key('about-terms'),
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms of use'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openLink(ctx, termsUrl),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Contact'),
              subtitle: const Text(contactEmail),
              onTap: () => openLink(ctx, 'mailto:$contactEmail?subject=Beam'),
            ),
            ListTile(
              key: const Key('about-community'),
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Join the HomiLabs community'),
              subtitle: const Text('New apps, early builds and a say in what we build next'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openLink(ctx, communityUrl),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Open-source licences'),
              onTap: () => showLicensePage(context: ctx, applicationName: 'Beam', applicationVersion: appVersion),
            ),
          ],
        ),
      ),
    ),
  ),
);

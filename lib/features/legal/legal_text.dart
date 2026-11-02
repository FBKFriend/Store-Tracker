class LegalText {
  LegalText._();

  static const lastUpdated = 'November 2026';
  static const developerName = 'Denmark Angelo C. Dela Cruz';
  static const developerTitle = 'Developer';
  static const contactEmail = 'delacruzdenmarkangelo107@gmail.com';

  static const intro =
      'My Sari-Sari Store is a free app for keeping records of a small '
      'store: inventory, sales and customer utang. It was made by '
      '$developerName as a student project.';

  static const privacyPoints = [
    'What the app stores: your items, stock, prices, sales, your customers\' '
        'names and what they owe, your store name and your settings. All of it '
        'is kept in a database on your phone, so the app works without internet.',
    'No ads, no tracking, no analytics. The developer does not receive, see '
        'or sell your data, and there is no account on any server of ours.',
    'If you sign in with Google, the app learns your Google name and email '
        'address, only to show who is signed in. It also asks permission to '
        'keep its own private backup files in a hidden app folder in your own '
        'Google Drive. It cannot see or change any of your other Drive files. '
        'Backups go straight from your phone to your Google Drive; the '
        'developer cannot open them.',
    'If you tap "Back up locally", the app saves your data as a file in '
        'Documents/MySariSariStore on your phone. This uses Android\'s "All '
        'files access" permission, which the app uses only for this file. '
        'Anyone who can open your phone\'s files can read it, and the PIN lock '
        'does not protect it.',
    'Your PIN, recovery answer and fingerprint setting stay on your phone. The '
        'PIN and recovery answer are stored scrambled (hashed) and are never '
        'part of a backup. Fingerprints are checked by Android; the app never '
        'sees them.',
    'You decide what to record about your customers. Record only what you '
        'need, such as a first name and what they owe. If you run a business, '
        'you may have your own duties under privacy laws, such as the '
        'Philippines\' Data Privacy Act.',
    'Printing: the inventory list and shopping list PDFs are made on your '
        'phone and go only where you send them.',
    'To delete your data: uninstall the app (this removes the data on your '
        'phone). To delete your Google Drive backups, open Google Drive, then '
        'Settings, Manage apps, My Sari-Sari Store, and choose "Delete hidden '
        'app data". To delete the backup file, delete the '
        'Documents/MySariSariStore folder on your phone.',
    'The app\'s use of information received from Google APIs follows the '
        'Google API Services User Data Policy, including its Limited Use '
        'requirements.',
    'If this policy changes, the new version will be shown in the app with a '
        'new date.',
  ];

  static const termsPoints = [
    'The app helps you keep records of your store\'s inventory, sales and '
        'customer utang. It is free.',
    'It is provided "as is", without any warranty. Figures such as profit, '
        'expenses and cash are for your own records and are not accounting, '
        'tax or legal advice.',
    'You are responsible for the accuracy of what you enter, for keeping your '
        'backups up to date, and for keeping your phone and PIN safe.',
    'The developer is not responsible for lost data (for example from a lost '
        'or damaged phone, a deleted app or a failed backup), or for business '
        'decisions made using the app.',
    'Please do not use the app for anything unlawful.',
    'Updates may change or remove features.',
  ];
}

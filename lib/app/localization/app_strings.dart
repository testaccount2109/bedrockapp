import '../../domain/entities/host_status.dart';

class AppStrings {
  const AppStrings(this.languageCode);

  final String languageCode;

  static const supportedLanguageCodes = <String>['de', 'en'];

  bool get isGerman => languageCode == 'de';

  String get appTitle => 'HostConnect';
  String get serversTab => isGerman ? 'Server' : 'Servers';
  String get optionsTab => isGerman ? 'Optionen' : 'Options';
  String get addServer => isGerman ? 'Server hinzufuegen' : 'Add server';
  String get editServer => isGerman ? 'Server bearbeiten' : 'Edit server';
  String get deleteServer => isGerman ? 'Server loeschen' : 'Delete server';
  String get favorite => isGerman ? 'Favorit' : 'Favorite';
  String get favorites => isGerman ? 'Favoriten' : 'Favorites';
  String get allServers => isGerman ? 'Alle Server' : 'All servers';
  String get search => isGerman ? 'Suchen' : 'Search';
  String get noServers => isGerman ? 'Keine Server gespeichert' : 'No servers saved';
  String get noSearchResults => isGerman ? 'Keine Treffer' : 'No results';
  String get name => isGerman ? 'Name' : 'Name';
  String get address => isGerman ? 'IP-Adresse' : 'IP address';
  String get port => isGerman ? 'Port' : 'Port';
  String get save => isGerman ? 'Speichern' : 'Save';
  String get cancel => isGerman ? 'Abbrechen' : 'Cancel';
  String get startHost => isGerman ? 'Host starten' : 'Start host';
  String get stopHost => isGerman ? 'Host stoppen' : 'Stop host';
  String get onlineStatus => isGerman ? 'Online Status' : 'Online status';
  String get activeServer => isGerman ? 'Aktiver Server' : 'Active server';
  String get transfers => isGerman ? 'Transfers' : 'Transfers';
  String get logs => isGerman ? 'Log Ausgabe' : 'Logs';
  String get language => isGerman ? 'Sprache' : 'Language';
  String get german => 'Deutsch';
  String get english => 'English';
  String get requiredField => isGerman ? 'Pflichtfeld' : 'Required field';
  String get invalidPort =>
      isGerman ? 'Port muss zwischen 1 und 65535 liegen' : 'Port must be 1 to 65535';
  String get confirmDelete =>
      isGerman ? 'Diesen Server wirklich loeschen?' : 'Delete this server?';
  String get noLogs => isGerman ? 'Noch keine Logs.' : 'No logs yet.';

  String statusLabel(HostRunState state) {
    return switch (state) {
      HostRunState.offline => isGerman ? 'Offline' : 'Offline',
      HostRunState.starting => isGerman ? 'Startet' : 'Starting',
      HostRunState.online => isGerman ? 'Online' : 'Online',
      HostRunState.stopping => isGerman ? 'Stoppt' : 'Stopping',
      HostRunState.failed => isGerman ? 'Fehler' : 'Failed',
    };
  }
}

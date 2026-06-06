import '../entities/server_profile.dart';

abstract interface class ServerRepository {
  Future<List<ServerProfile>> listProfiles();
  Future<void> saveProfile(ServerProfile profile);
  Future<void> deleteProfile(String id);
  Future<ServerProfile?> getProfile(String id);
}

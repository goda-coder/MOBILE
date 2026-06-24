import 'package:multicast_dns/multicast_dns.dart';

class DiscoveryService {
  final MDnsClient _client = MDnsClient();
  Future<List<DiscoveredDevice>> discover() async {
    final devices = <DiscoveredDevice>[];

    await _client.start();
    try {
      await for (final ptr in _client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer("_ws._tcp.local"))) {
        await for (final srv in _client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final ip in _client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(
              srv.target,
            ),
          )) {
            devices.add(
              DiscoveredDevice(
                name: ptr.domainName,
                host: ip.address.address,
                port: srv.port,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Ignore lookup errors
    } finally {
      _client.stop();
    }

    return devices;
  }
}

class DiscoveredDevice {
  final String name;
  final String host;
  final int port;

  DiscoveredDevice({
    required this.name,
    required this.host,
    required this.port,
  });
}

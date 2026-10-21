import 'package:flutter/foundation.dart';

/// Aviso interno de que pudo llegar una notificación nueva (por ejemplo, un
/// push con la app abierta): quien muestre el contador de la bandeja lo
/// vuelve a consultar. Vive aparte para no arrastrar Firebase a las pantallas.
final ValueNotifier<int> inboxEvents = ValueNotifier<int>(0);

void notifyInboxChanged() => inboxEvents.value++;

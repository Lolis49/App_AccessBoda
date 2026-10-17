# Panel de estadísticas de L&J

El módulo ya está integrado. Estos pasos explican cómo está conectado y dónde
encontrar el código completo para revisarlo o ampliarlo.

## 1. Calcular los indicadores

Archivo: `lib/models/attendance_statistics.dart`.

`AttendanceStatistics.fromGuests` recibe todas las invitaciones y calcula:

- Personas invitadas, ingresadas y pendientes.
- Adultos y niños, con sus respectivos ingresos y pendientes.
- Invitaciones completas, parciales y sin ingresos, usando `Guest.status`.
- Asistencia por mesa, ordenada numéricamente; las invitaciones sin mesa
  se agrupan al final.

Un pase puede representar varias personas. El porcentaje general usa personas:

```dart
double get progress => invited == 0 ? 0 : checkedIn / invited;
```

Esto evita dividir entre cero cuando todavía no hay invitados.
Las barras por mesa comparan ingresos con personas asignadas; no representan
la capacidad física ni cuántas personas están sentadas en ese momento.

## 2. Leer la base de datos

Archivo: `lib/services/database_service.dart`.

Se agregó el import del modelo y este método dentro de `DatabaseService`:

```dart
Future<AttendanceStatistics> getAttendanceStatistics() async {
  return AttendanceStatistics.fromGuests(await getGuests());
}
```

Se reutiliza la base SQLite actual, sin migraciones ni dependencias nuevas.
La lectura abarca todas las invitaciones; la búsqueda de Inicio no la filtra.
El método `getStatistics()` existente sigue alimentando el resumen de Inicio.

## 3. Mostrar el panel

Código completo: `lib/screens/statistics_screen.dart`.

`StatisticsScreen` lee los datos al abrirse y muestra cuatro secciones:
asistencia general, estado de invitaciones, adultos y niños y asistencia por mesa.
Reutiliza `StatCard`, `AppColors` y el tema actual de la aplicación.

Incluye estado de carga, mensaje sin invitados y botón para reintentar si falla
la lectura. El botón de actualizar y el gesto de deslizar hacia abajo vuelven
a consultar la base. Los datos son locales a este dispositivo y no se sincronizan
automáticamente con otros teléfonos. La hora mostrada corresponde a la última
lectura completada; el panel no se actualiza por temporizador.

## 4. Abrirlo desde Inicio

Archivo: `lib/screens/home_screen.dart`.

```dart
import 'statistics_screen.dart';
```

Dentro de `_HomeScreenState` se agregó:

```dart
Future<void> _openStatistics() async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const StatisticsScreen()),
  );
  if (mounted) await _loadData();
}
```

El botón dentro de `_buildSummary()` abre el panel:

```dart
OutlinedButton.icon(
  onPressed: _openStatistics,
  icon: const Icon(Icons.bar_chart),
  label: const Text('Ver panel de estadísticas'),
),
```

## 5. Comprobar el funcionamiento

Reinicia la aplicación, abre **Ver panel de estadísticas** y verifica los totales.
Registra parte de una invitación desde el flujo habitual y vuelve a abrir el panel:
el pase debe quedar parcial y sus personas pendientes deben disminuir.
Completa la invitación y comprueba que pase a completo.

Para ejecutar las pruebas específicas:

```sh
flutter test test/attendance_statistics_test.dart test/statistics_screen_test.dart
```

Las pruebas de cálculo cubren conjuntos vacíos, ingresos parciales y agrupación
por mesa. Las de pantalla cubren actualización, recuperación de errores,
estado vacío y visualización en un teléfono de 320 píxeles de ancho.

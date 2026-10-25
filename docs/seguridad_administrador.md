# PIN de administrador

## Uso

1. Detén y vuelve a ejecutar la aplicación: se agregó un plugin nativo.
2. En Inicio, pulsa el escudo **Configurar o cambiar PIN de administrador**.
3. Crea y confirma un PIN de 6 dígitos antes de entregar el teléfono al personal.
   No existe un PIN predeterminado. Si aún no está configurado, la primera
   operación administrativa también ofrece crearlo.
4. Al seleccionar un Excel se pide el PIN antes de abrir el selector de archivos.
5. Reiniciar pruebas pide el PIN y conserva la confirmación de borrado posterior.
6. Para cambiar el PIN, pulsa el escudo, verifica el PIN actual y confirma el nuevo.

El escáner, registro de entradas, lista y estadísticas siguen disponibles para
la operación habitual. No hay una sesión de administrador abierta: cada operación
requiere autorización. Cancelar no ejecuta la acción. Si un archivo tarda más de
5 minutos en seleccionarse, vuelve a iniciar la importación para autorizarla.

## Implementación

- `admin_security_service.dart`: PBKDF2-HMAC-SHA256, 100000 iteraciones y sal
  aleatoria de 32 bytes; guarda el verificador, nunca el PIN en texto plano.
- `flutter_secure_storage`: almacenamiento seguro de la plataforma. El PIN no
  se guarda en SQLite ni en el Excel/JSON.
- Cinco verificaciones incorrectas bloquean por 30 segundos. Contador y fecha
  de desbloqueo se guardan junto con el verificador y sobreviven al cierre de la app.
- Permisos por acción, de un solo uso y con vencimiento a los 5 minutos.
- `DatabaseService.importGuests` y `resetAllCheckIns` exigen un permiso válido
  antes de consultar SQLite. Las rutas de importación JSON/Excel también lo exigen.
- Cambiar el PIN invalida los permisos anteriores. Un error de lectura o escritura
  del almacenamiento seguro no concede acceso ni sustituye la configuración.
- Android desactiva Auto Backup para evitar restaurar datos cifrados sin sus claves;
  esto también desactiva la copia automática de los datos locales de la aplicación.
- macOS incluye los permisos de Keychain en ambos archivos de entitlements.

Para nuevas funciones administrativas, añade una entrada a `AdminAction`, pide
un permiso con `requestAdminAuthorization` y exige ese permiso en el servicio
que ejecuta la operación, consumiéndolo antes de modificar datos.

## Alcance y recuperación

El PIN protege funciones dentro de la aplicación en este dispositivo. No crea
usuarios ni sincroniza credenciales entre teléfonos, ni cifra toda la base de
invitados. No es una barrera frente a una aplicación modificada o un dispositivo
comprometido. El bloqueo temporal utiliza el reloj del dispositivo.

Guarda el PIN fuera del teléfono: no se implementó recuperación ni una clave
maestra. Si se pierde, se necesita un procedimiento de recuperación autorizado;
no borres datos o desinstales como solución porque puedes perder invitados e
historial. En iOS, el almacenamiento Keychain puede persistir tras reinstalar.

Las pruebas automatizadas verifican lógica y diálogos con almacenamiento simulado;
la persistencia nativa debe comprobarse en el teléfono con una compilación nueva.

La comprobación local de Android quedó pendiente: faltan dependencias de Gradle
del plugin de almacenamiento seguro en la caché. Se necesita acceso a los
repositorios de Google/Maven al ejecutar `flutter run`. Si se ejecuta Gradle
directamente desde la terminal, debe usarse el JDK de Android Studio; el Java 8
predeterminado de esta máquina no sirve para compilar este proyecto.

```sh
flutter test test/admin_security_service_test.dart test/admin_pin_dialog_test.dart
```

Prueba manual en el teléfono: configura el PIN, cierra y abre la app, comprueba
que un PIN incorrecto no permita importar, selecciona un Excel con el PIN correcto
y verifica el cambio de PIN. Para probar el reinicio usa una copia de datos de
prueba; la confirmación posterior al PIN elimina realmente las entradas e historial.

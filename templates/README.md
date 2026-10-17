# Importar invitados desde Excel

Abre `invitados_boda.xlsx` y reemplaza la fila de ejemplo por tus invitados.
Guarda como Excel `.xlsx` y selecciona el archivo en **Importar invitados**.
Se importa la primera hoja que contenga datos. La primera fila con datos debe
contener los encabezados; el orden de las columnas puede variar.

| Folio | Nombre | Adultos | Niños | Mesa |
| --- | --- | --- | --- | --- |
| TEST2027 | Familia de ejemplo | 2 | 1 | 8 |

- Folio: único, 8 letras o números. Usa formato Texto para conservar ceros iniciales.
- Nombre: obligatorio.
- Adultos y Niños: enteros no negativos, con al menos una persona por invitación.
- Mesa: entero positivo opcional. Vacío conserva la mesa existente al actualizar.
- Usa valores directos, sin fórmulas. Las filas vacías se omiten.
- Tamaño máximo: 5 MB. No admite `.xls` ni archivos protegidos con contraseña.

La aplicación convierte el Excel a JSON en memoria y valida todos los datos
antes de guardarlos. Los folios existentes se actualizan y los nuevos se agregan;
se conservan las entradas registradas. Los invitados ausentes del archivo no se eliminan.

# UCalendar

Implementación en Rails de [uc-nrc-icalendar][uc-nrc-icalendar].

Aplicación web que obtiene los cursos de [Busca Cursos][buscacursosuc]
y crea un calendario en formato [iCalendar][iCal] que luego puede ser
importado a Google Calendar.

[Deploy en Heroku][deploy-page]


## Uso

1. Seleccionar el semestre académico.
2. Ingresar los códigos del curso junto a su sección (`EJM1230-1`) o
   el NRC de cada uno.
3. Descargar el calendario `ics` o copiar el `url` de descarga.
4. Agregar el calendario a la aplicación de calenadrio con el
   acrhivo `ics` (en [google][gc-by-ics])
   o con el `url` (en [google][gc-by-url]).


## Set-Up

Antes de crear la base de datos, crear un archivo`.env` con la clave
de postgres y el host de BuscaCursos:

```env
POSTGRES_PASSWORD=
BC_HOST=
FLYYER_KEY=<optional>
```

Para crear el entorno de desarrollo:

```bash
bundle install
yarn install
rails db:setup
```

Para iniciar el servidor

```bash
sudo service postgresql start
rails s
```


### Administración

Para que se pueda obtener los cursos, tiene que existir un periodo
académico (_term_) en la base de datos. Tambíen, para que no se creen
eventos en feriados deben crearse estos feriados (_holidays_).

Estos se pueden crear con las _seeds_ o en el interfaz de
administración (`/admin`).


## Obtener los calendarios externamente

```js
HOST = 'https://ucalendar.osuc.dev'
```

### Directo

```js
`${HOST}/term/${year}/${period}/schedule.ics?cs[]=${cs}&nrc[]=${nrc}`
```

- `year`: año buscado, requerido
- `period`: periodo buscado, requerido
- `cs[]`: curso con su sección (ej `MAT1610-1`), opcional, acepta multiples valores
- `nrc[]`: ncr del curso, opcional, acepta multiples valores

Ejemplo:

```url
https://ucalendar.osuc.dev/term/2021/1/schedule.ics?cs[]=MAT1640-1&cs[]=MAT1630-1
```

### Versíon corta

```js
`${HOST}?s.ics?year=${year}&period=${period}&cs=${course_section}&nrc=${nrc}`
```

Acepta los mismos parámetros de el `GET`, pero `year` y `period` son
opcionales, si no están presentes obtienen los datos de la el periodo
académico.

Además, acepta:

- `cs`: cursos coon su sección separados por comas
- `nrc`: nrc de los cursos separados por comas

Ejemplos (formato HTML):

```url
https://ucalendar.osuc.dev/s.ics?cs=MAT1640-1,MAT1630-1
```

### Ver periodos

```js
`${HOST}/terms.json`
```

Obtiene una lista de los periodos académicos en formato `JSON`.


## GH Pages (Página estática)

Ya que se utiliza una vista con AJAX, esta puede ser compilada a
una [página estática]. Para esto se usa la rama `gh-pages`, que es
creada con la página con el comando `rake gh_pages:compile`.

Página en [github.io][gh-page].


## Links adicionales

- Página con documentación de icalendar: [icalendar.org]
- Diagrama de la base de datos en: [dbdiagram.io]


<!-- Links -->

[buscacursosuc]:      http://buscacursos.uc.cl/
[uc-nrc-icalendar]: https://github.com/benjavicente/uc-nrc-icalendar
[ical]:             https://es.wikipedia.org/wiki/ICalendar
[icalendar.org]:    https://icalendar.org/
[dbdiagram.io]:     https://dbdiagram.io/d/5fd964db9a6c525a03bb3aee
[página estática]:  https://es.wikipedia.org/wiki/P%C3%A1gina_web_est%C3%A1tica
[gc-by-ics]:        https://calendar.google.com/calendar/u/0/r/settings/export
                    "Importar en Google Calendar con archivo ICS"
[gc-by-url]:        https://calendar.google.com/calendar/u/0/r/settings/addbyurl
                    "Importar en Google Calendar con URL del calendario"
[gh-page]:          https://benjavicente.github.io/ucalendar/
[deploy-page]:      https://ucalendar.osuc.dev/

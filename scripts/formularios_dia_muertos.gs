/**
 * Crea los dos formularios de Google Forms para los Concursos de Día de Muertos
 * (Taller de Cómputo, Lic. en Matemáticas para el Desarrollo, ENES Juriquilla).
 *
 * Uso:
 *   1. Abre https://script.google.com  →  "Nuevo proyecto".
 *   2. Borra el contenido, pega este archivo completo y guarda (Ctrl/Cmd + S).
 *   3. Elige la función `crearFormularios` y presiona "Ejecutar". Autoriza los permisos.
 *   4. En "Registro de ejecución" aparecen los enlaces de edición y de respuesta.
 *   5. En cada formulario agrega a mano la pregunta "Subir archivo" (Apps Script no
 *      puede crearla; ver las instrucciones en el registro).
 */

function crearFormularios() {
  const f1 = crearConcursoEsqueleto();
  const f2 = crearConcursoCalaverita();
  [f1, f2].forEach(function (f) {
    Logger.log('\n%s\n  Editar:    %s\n  Responder: %s', f.getTitle(), f.getEditUrl(), f.getPublishedUrl());
  });
  Logger.log('\nFALTA (manual): en cada formulario, debajo de la sección "📎 Archivo PDF", ' +
    'agrega una pregunta tipo "Subir archivo": 1 archivo, solo PDF, tamaño máximo 10 MB, obligatoria.');
}

// ---------------------------------------------------------------------------
// Concurso 1
// ---------------------------------------------------------------------------
function crearConcursoEsqueleto() {
  const form = nuevoFormulario(
    '💀 Concurso 1. Decora tu esqueleto',
    'Transforma un esqueleto de papel en un personaje creativo relacionado con la bioinformática, ' +
    'la programación o los temas estudiados en Taller de Cómputo.\n\n' +
    'Para participar y ser considerado(a) en la premiación es OBLIGATORIO realizar ambas entregas:\n' +
    '  1. Digital: un único PDF (Esqueleto_Nombre_Apellido.pdf) con tu nombre y grupo, el nombre del ' +
    'personaje, la explicación escrita (50 a 100 palabras) y al menos una fotografía a color del esqueleto completo.\n' +
    '  2. Física: el esqueleto original, recortado, armado y decorado, en la fecha y lugar indicados por la profesora.\n\n' +
    'Rúbrica (100 pts): Creatividad y originalidad 30 · Relación con la materia 30 · ' +
    'Decoración y presentación 20 · Armado y funcionalidad 10 · Nombre y explicación 10.\n\n' +
    '🥇🥈🥉 Habrá tres ganadores.'
  );

  datosEstudiante(form);

  form.addPageBreakItem().setTitle('Tu personaje');
  form.addTextItem()
    .setTitle('Nombre del personaje')
    .setHelpText('¿Cómo se llama tu esqueleto?')
    .setRequired(true);
  form.addParagraphTextItem()
    .setTitle('Explicación escrita (50 a 100 palabras)')
    .setHelpText('Inspiración: ¿qué concepto de bioinformática, programación o Taller de Cómputo representa? ' +
      'Diseño: ¿por qué elegiste esa decoración, vestimenta o accesorios? ' +
      'Materiales: ¿qué usaste y cuáles son reciclados o reutilizados? (Debe coincidir con la del PDF).')
    .setRequired(true)
    .setValidation(FormApp.createParagraphTextValidation()
      .requireTextMatchesPattern('^\\s*(\\S+\\s+){49,99}\\S+\\s*$')
      .setHelpText('La explicación debe tener entre 50 y 100 palabras.')
      .build());
  form.addCheckboxItem()
    .setTitle('Materiales reciclados o reutilizados que usaste')
    .setChoiceValues(['Cartón', 'Papel', 'Telas', 'Tapas', 'Empaques', 'No usé materiales reciclados'])
    .showOtherOption(true)
    .setRequired(true);
  form.addMultipleChoiceItem()
    .setTitle('¿Cómo presentarás tu esqueleto en la entrega física?')
    .setChoiceValues([
      'Articulado: con sus extremidades unidas de manera que puedan moverse',
      'Fijo: sobre una base decorativa creando una escena o fondo relacionado con el personaje'
    ])
    .setRequired(true);

  seccionArchivo(form, 'Esqueleto_Nombre_Apellido.pdf',
    'Debe incluir nombre y grupo, nombre del personaje, explicación escrita y al menos una fotografía a color ' +
    'del esqueleto completo, con buena iluminación, enfocada y con el texto completamente legible.');

  confirmaciones(form, [
    'Entregaré físicamente mi esqueleto original, completo y en buenas condiciones, en la fecha y lugar indicados por la profesora.',
    'Mi diseño respeta las normas de contenido (sin contenido obsceno, ofensivo, discriminatorio o violento, ni apología de drogas o alcohol).',
    'Mi archivo es un único PDF llamado Esqueleto_Nombre_Apellido.pdf.'
  ]);
  return form;
}

// ---------------------------------------------------------------------------
// Concurso 2
// ---------------------------------------------------------------------------
function crearConcursoCalaverita() {
  const form = nuevoFormulario(
    '✍️ Concurso 2. Calaveritas literarias: ¡La Catrina visita a mis profesores!',
    'Escribe una calaverita literaria original, divertida y respetuosa, inspirada en uno o varios profesores ' +
    'que te imparten clases en este primer semestre de la Lic. en Matemáticas para el Desarrollo.\n\n' +
    'Requisitos: título original; de 3 a 5 estrofas de 4 versos con rima (se recomiendan versos de ~8 sílabas); ' +
    'humor, ingenio y un desenlace divertido; siempre con respeto.\n\n' +
    'Entrega: un único PDF (Calaverita_Nombre_Apellido.pdf) con la hoja DECORADA A MANO con motivos de Día de ' +
    'Muertos, escaneada o fotografiada (recomendado 300 dpi). No se aceptan decoraciones digitales ni imágenes impresas.\n\n' +
    'Rúbrica (100 pts): Creatividad y originalidad 25 · Humor y picardía 25 · Rima, ritmo y estructura 20 · ' +
    'Relación con los profesores 20 · Coherencia, ortografía y presentación 10.\n\n' +
    '🥇🥈🥉 Habrá tres ganadores.'
  );

  datosEstudiante(form);

  form.addPageBreakItem().setTitle('Tu calaverita');
  form.addTextItem()
    .setTitle('Título de la calaverita')
    .setRequired(true);
  form.addTextItem()
    .setTitle('Profesor(es) que aparecen en tu calaverita')
    .setHelpText('Al menos un profesor que actualmente te imparta clases.')
    .setRequired(true);
  form.addMultipleChoiceItem()
    .setTitle('Número de estrofas (de 4 versos cada una)')
    .setChoiceValues(['3', '4', '5'])
    .setRequired(true);

  seccionArchivo(form, 'Calaverita_Nombre_Apellido.pdf',
    'Debe contener la calaverita completa: título, texto y toda la decoración hecha a mano. ' +
    'Ábrelo antes de subirlo y verifica que el texto sea legible, sin sombras, reflejos, partes recortadas ni imágenes borrosas.');

  confirmaciones(form, [
    'Mi calaverita es de creación propia; no es copiada ni fue generada íntegramente con inteligencia artificial.',
    'La hoja fue decorada a mano antes de digitalizarla (sin decoraciones digitales ni imágenes impresas).',
    'Mi calaverita es respetuosa: sin insultos, burlas discriminatorias ni ataques personales.',
    'Mi archivo es un único PDF llamado Calaverita_Nombre_Apellido.pdf.'
  ]);
  return form;
}

// ---------------------------------------------------------------------------
// Piezas compartidas
// ---------------------------------------------------------------------------
function nuevoFormulario(titulo, descripcion) {
  const form = FormApp.create(titulo)
    .setDescription(descripcion)
    .setCollectEmail(true)
    .setAllowResponseEdits(true)
    .setProgressBar(true)
    .setConfirmationMessage('¡Gracias por participar! 💀 Tu registro quedó guardado.');
  try { form.setPublished(true); } catch (e) { /* versiones sin publicación explícita */ }
  return form;
}

function datosEstudiante(form) {
  form.addTextItem().setTitle('Nombre completo').setRequired(true);
  form.addTextItem()
    .setTitle('Número de cuenta')
    .setRequired(true)
    .setValidation(FormApp.createTextValidation()
      .requireTextMatchesPattern('^\\d{9}$')
      .setHelpText('Escribe tu número de cuenta de 9 dígitos, sin guiones.')
      .build());
  form.addTextItem().setTitle('Grupo').setRequired(true);
}

function seccionArchivo(form, nombreArchivo, detalle) {
  form.addPageBreakItem()
    .setTitle('📎 Archivo PDF')
    .setHelpText('Nombre del archivo: ' + nombreArchivo + '\n' + detalle);
}

function confirmaciones(form, frases) {
  form.addCheckboxItem()
    .setTitle('Antes de enviar, confirma lo siguiente')
    .setChoiceValues(frases)
    .setRequired(true)
    .setValidation(FormApp.createCheckboxValidation()
      .requireSelectExactly(frases.length)
      .setHelpText('Debes marcar todas las casillas para participar.')
      .build());
}

"""Convierte una actividad del libro (.qmd con editores {pyodide}) en:
- un notebook .ipynb para Google Colab y Jupyter Notebook, o
- un .qmd para que cada estudiante lo trabaje en RStudio.
El formato de salida se elige con la extensión del archivo.

Uso:
    python scripts/qmd_a_ipynb.py python_ejercicio1.qmd notebooks/actividad1.ipynb
    python scripts/qmd_a_ipynb.py python_ejercicio1.qmd notebooks/actividad1.qmd

Conversiones:
- {python} y {pyodide}            -> celdas de código (sin las opciones #|)
- {pyodide} con check: true       -> celda de verificación (revisa la variable `respuesta`)
- .hint / .solution               -> bloques desplegables <details>
- callouts                        -> citas (>) con título
- figures/... y enlaces a .qmd    -> URLs de GitHub y del libro publicado
"""
import json
import re
import sys

REPO_RAW = "https://raw.githubusercontent.com/EveliaCoss/Mt2026_Taller_Computo_libro/main/"
LIBRO = "https://eveliacoss.github.io/Mt2026_Taller_Computo_libro/"
COLAB = "https://colab.research.google.com/github/EveliaCoss/Mt2026_Taller_Computo_libro/blob/main/"

# Secciones del .qmd que solo tienen sentido dentro del libro
SECCIONES_OMITIDAS = ("¿Cómo usar los editores", "¿Dónde hacer esta actividad?", "Abrir Python en RStudio")
NO_ES_EXPRESION = re.compile(r"^(print\(|#|import |from |\w[\w, \[\]]*\s*[+\-*/]?=[^=])")
TITULOS_CALLOUT = {"note": "📝 Nota", "tip": "💡 Consejo", "important": "❗ Importante", "warning": "⚠️ Advertencia"}


def adaptar_texto(linea):
    linea = re.sub(r"!\[([^\]]*)\]\((figures/[^)]+)\)(\{[^}]*\})?", lambda m: f"![{m[1]}]({REPO_RAW}{m[2]})", linea)
    linea = re.sub(r"\]\(([\w-]+)\.qmd(#[^)]*)?\)", lambda m: f"]({LIBRO}{m[1]}.html{m[2] or ''})", linea)
    return linea


def celda(tipo, lineas):
    texto = "\n".join(lineas).strip("\n")
    c = {"cell_type": tipo, "metadata": {}, "source": texto.splitlines(keepends=True)}
    if tipo == "code":
        c.update(outputs=[], execution_count=None)
    return c


def convertir(ruta_qmd, ruta_ipynb):
    lineas = open(ruta_qmd, encoding="utf-8").read().split("\n")
    if lineas[0].strip() == "---":                       # quitar el encabezado YAML
        lineas = lineas[lineas.index("---", 1) + 1:]

    celdas, md = [], []
    con_verificacion = set()                           # ejercicios que tienen celda ✅ Verificar
    ejercicio = ""
    omitir_nivel = None
    i = 0

    def guardar_md():
        if any(l.strip() for l in md):
            celdas.append(celda("markdown", md))
        md.clear()

    while i < len(lineas):
        linea = lineas[i]
        encabezado = re.match(r"^(#{1,6}) (.*)", linea)

        if encabezado:
            nivel, titulo = len(encabezado[1]), encabezado[2]
            if omitir_nivel is None and nivel <= 3:
                guardar_md()                               # una celda de texto por sección
            if omitir_nivel is not None and nivel <= omitir_nivel:
                omitir_nivel = None
            if omitir_nivel is None and titulo.startswith(SECCIONES_OMITIDAS):
                omitir_nivel = nivel
            if m := re.match(r"Ejercicio (\d+)", titulo):
                ejercicio = m[1]
        if omitir_nivel is not None or linea.startswith("{{<"):
            i += 1
            continue

        bloque = re.match(r"^```\{(\w+)", linea)
        if bloque:                                         # bloques de código ejecutables
            fin = lineas.index("```", i + 1)
            cuerpo = lineas[i + 1:fin]
            opciones = [l for l in cuerpo if l.startswith("#|")]
            codigo = [l for l in cuerpo if not l.startswith("#|")]
            i = fin + 1
            if bloque[1] not in ("python", "pyodide"):     # p. ej. bloques {r} ocultos
                continue
            guardar_md()
            if any("check: true" in o for o in opciones):
                # El ejercicio guarda su última expresión en `respuesta` para poder revisarla
                ej = celdas[-1]["source"]
                k = max(n for n, l in enumerate(ej) if l.strip())
                ultima = ej[k].rstrip("\n")
                if not NO_ES_EXPRESION.match(ultima.strip()):
                    ej[k:k + 1] = [f"respuesta = {ultima}\n", "respuesta"]
                con_verificacion.add(ejercicio)
                celdas.append(celda("code", [
                    f'#@title ✅ Verificar el ejercicio {ejercicio} {{ display-mode: "form" }}',
                    "# Ejecuta esta celda después de ejecutar tu solución",
                    "result = respuesta",
                    *codigo,
                    'print(("✅ " if feedback["correct"] else "❌ ") + feedback["message"])',
                ]))
            else:
                celdas.append(celda("code", codigo))
            continue

        div = re.match(r"^:::+ *\{\.(hint|solution)", linea)
        if div:                                            # pistas y soluciones -> desplegables
            profundidad, j, contenido = 1, i + 1, []
            while profundidad:
                l = lineas[j]
                if re.match(r"^:::+\s*$", l):
                    profundidad -= 1
                elif l.startswith(":::"):
                    profundidad += 1
                elif not re.match(r"^## (Pista|Solución)", l):
                    contenido.append(adaptar_texto(l))
                j += 1
            guardar_md()
            if div[1] == "solution" and ejercicio in con_verificacion:
                # La solución también guarda su resultado en `respuesta`
                fin = max(n for n, l in enumerate(contenido) if l.strip().startswith("```") and not l.strip().startswith("``` python") and l.strip() != "```python")
                k = max(n for n in range(fin) if contenido[n].strip())
                if not NO_ES_EXPRESION.match(contenido[k].strip()):
                    contenido[k:k + 1] = [f"respuesta = {contenido[k]}", "respuesta"]
            resumen = "💡 Pista" if div[1] == "hint" else "✔️ Solución"
            celdas.append(celda("markdown", ["<details>", f"<summary><b>{resumen}</b> (da clic para ver)</summary>", "", *contenido, "", "</details>"]))
            i = j
            continue

        callout = re.match(r"^:::+ *\{?\.?callout-(\w+)", linea)
        if callout:                                        # callouts -> citas con título
            j, contenido = i + 1, []
            titulo = TITULOS_CALLOUT.get(callout[1], "Nota")
            if lineas[j].startswith("## "):
                titulo, j = lineas[j][3:], j + 1
            while not re.match(r"^:::+\s*$", lineas[j]):
                contenido.append(adaptar_texto(lineas[j]))
                j += 1
            md.extend(["", f"> **{titulo}**", ">", *[f"> {l}" if l else ">" for l in contenido], ""])
            i = j + 1
            continue

        md.append(adaptar_texto(re.sub(r"^```\s+$", "```", linea)))
        i += 1
    guardar_md()

    ipynb = ruta_ipynb.replace("\\", "/").replace(".qmd", ".ipynb")
    pasos_comunes = [
        "3. Completa los espacios `______` de cada ejercicio.",
        "4. Da clic en **💡 Pista** o **✔️ Solución** para desplegarlas.",
        "5. En los ejercicios con **✅ Verificar**, ejecuta primero tu solución y después la celda de verificación.",
    ]
    if ruta_ipynb.endswith(".qmd"):
        bienvenida = celda("markdown", [
            f"Esta es la versión para **RStudio** de la actividad del [libro del curso]({LIBRO}{ruta_qmd.replace('.qmd', '.html')}). Es **tu propio archivo**: escribe tus respuestas aquí y guárdalo.",
            "",
            "**Antes de empezar:**",
            "",
            "1. Cambia `Tu nombre` por tu nombre en el encabezado (YAML) del archivo.",
            "2. Ejecuta los bloques **en orden**, de arriba hacia abajo, con el botón ▶ de cada bloque (o `Cmd/Ctrl + Shift + Enter`).",
            *pasos_comunes,
            "6. Al terminar, presiona **Render** para generar tu documento HTML con todos tus resultados.",
        ])
    else:
        bienvenida = celda("markdown", [
            f"[![Abrir en Colab](https://colab.research.google.com/assets/colab-badge.svg)]({COLAB}{ipynb})",
            "",
            f"Este notebook es la versión para **Google Colab** y **Jupyter Notebook** de la actividad del [libro del curso]({LIBRO}{ruta_qmd.replace('.qmd', '.html')}).",
            "",
            "**Antes de empezar:**",
            "",
            "1. En Google Colab, guarda tu propia copia: **Archivo → Guardar una copia en Drive**. Si no lo haces, tus cambios se perderán.",
            "2. Ejecuta las celdas **en orden**, de arriba hacia abajo, con `Shift + Enter`.",
            *pasos_comunes,
            "6. Si la sesión se desconecta, usa **Entorno de ejecución → Ejecutar todas** (Colab) o **Run → Run All Cells** (Jupyter).",
        ])
    celdas.insert(1, bienvenida)

    if ruta_ipynb.endswith(".qmd"):
        escribir_qmd(celdas, ruta_ipynb)
    else:
        escribir_ipynb(celdas, ruta_ipynb)
    print(f"{ruta_ipynb}: {len(celdas)} celdas")


def escribir_ipynb(celdas, ruta):
    notebook = {
        "nbformat": 4, "nbformat_minor": 5, "cells": celdas,
        "metadata": {
            "kernelspec": {"name": "python3", "display_name": "Python 3", "language": "python"},
            "language_info": {"name": "python"},
            "colab": {"provenance": [], "toc_visible": True},
        },
    }
    for n, c in enumerate(notebook["cells"]):
        c["id"] = f"celda-{n:03d}"
    with open(ruta, "w", encoding="utf-8") as f:
        json.dump(notebook, f, ensure_ascii=False, indent=1)


def escribir_qmd(celdas, ruta):
    titulo = "".join(celdas[0]["source"]).splitlines()[0].lstrip("# ").replace('"', "'")
    partes = ["---", f'title: "{titulo}"', 'author: "Tu nombre"', "format: html", "jupyter: python3",
              "execute:", "  error: true   # Muestra los errores sin detener el documento", "---", ""]
    celdas[0]["source"] = "".join(celdas[0]["source"]).split("\n", 1)[1:]      # el título ya está en el YAML
    for c in celdas:
        texto = "".join(c["source"]).strip("\n")
        if c["cell_type"] == "code":
            texto = re.sub(r'^#@title (.*?) \{.*\}$', r"# \1", texto, flags=re.M)
            partes += ["```{python}", texto, "```", ""]
        else:
            partes += [texto, ""]
    with open(ruta, "w", encoding="utf-8") as f:
        f.write("\n".join(partes))


if __name__ == "__main__":
    convertir(sys.argv[1], sys.argv[2])

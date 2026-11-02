"""Funciones del proyecto integrador: atlas de cónicas rotadas.

Las funciones de este ejemplo están INCOMPLETAS y tienen ERRORES A PROPÓSITO:
completarlas y corregirlas es parte de su trabajo.
  1. Completen cada ______.
  2. Cada línea marcada con 🐞 tiene un error: deben cambiar algo para corregirlo.
  3. Comprueben sus correcciones con las pruebas (assert) de la página Análisis.
En su entrega, las funciones deben mostrarse en la página Análisis (analisis.qmd)
para que las profesoras puedan revisarlas.
"""
import numpy as np
import sympy as sp

x, y, u, v = sp.symbols("x y u v", real=True)


def coeficientes(expresion):
    """Regresa los coeficientes A, B, C, D, E, F de Ax² + Bxy + Cy² + Dx + Ey + F."""
    P = sp.Poly(expresion, x, y)
    monomios = ______                                # Lista de los seis monomios, en el orden de A, B, C, D, E, F
    return [P.coeff_monomial(m) for m in monomios]


def clasificar_conica(A, B, C):
    """Clasifica la cónica según el discriminante B² - 4AC."""
    if A == 0 or B == 0 or C == 0:                   # 🐞 ¿Esta validación rechaza cónicas que sí son válidas? Pruébenla con xy = 4.
        raise ValueError("No es una ecuación de segundo grado: A, B y C son cero")
    discriminante = ______                           # Escriban ustedes la fórmula del discriminante.
    if discriminante > 0:                            # 🐞 ¿Qué signo tiene el discriminante de una elipse?
        return "elipse"
    elif ______:                                     # ¿Cuándo es parábola?
        return "parábola"
    else:
        return "hipérbola"


def angulo_rotacion(A, B, C):
    """Ángulo θ (en radianes) que elimina el término xy: tan(2θ) = B / (A - C)."""
    if B == 0:
        return ______                                # Sin término xy: ¿cuánto hay que rotar?
    if A == C:
        return sp.pi / 2                             # 🐞 Si 2θ = 90°, ¿cuánto vale θ?
    return sp.atan((A - C) / B) / 2                  # 🐞 Revisen la fracción con el docstring.


def rotar_ecuacion(expresion, theta):
    """______"""
    ______


def matriz_rotacion(theta):
    """Matriz de rotación de NumPy (2 × 2) para un ángulo theta en radianes."""
    ______


def plano_cartesiano(ax, limite=3):
    """Prepara ax como plano cartesiano: ejes en el origen, misma escala y cuadrícula."""
    ax.axhline(0, color="black", linewidth=0.8)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlim(-limite, limite)
    ax.set_ylim(-limite, limite)
    ax.set_aspect("equal")
    ax.grid(True, alpha=0.3)

"""Funciones del proyecto integrador: atlas de cónicas rotadas."""
import numpy as np
import sympy as sp

x, y, u, v = sp.symbols("x y u v", real=True)


def coeficientes(expresion):
    """Regresa [A, B, C, D, E, F] de la cónica Ax² + Bxy + Cy² + Dx + Ey + F = 0."""
    P = sp.Poly(expresion, x, y)
    return [P.coeff_monomial(m) for m in (x**2, x*y, y**2, x, y, 1)]


def clasificar_conica(A, B, C):
    """Clasifica la cónica según el discriminante B² - 4AC."""
    if A == 0 and B == 0 and C == 0:
        raise ValueError("No es una ecuación de segundo grado: A, B y C son cero")
    discriminante = B**2 - 4*A*C
    if discriminante < 0:
        return "elipse"
    elif discriminante == 0:
        return "parábola"
    else:
        return "hipérbola"


def angulo_rotacion(A, B, C):
    """Ángulo θ exacto (radianes) que elimina el término xy: tan(2θ) = B / (A - C)."""
    if B == 0:
        return sp.Integer(0)
    if A == C:
        return sp.pi / 4
    return sp.atan(sp.nsimplify(B) / sp.nsimplify(A - C)) / 2


def rotar_ecuacion(expresion, theta):
    """Sustituye x = u cos θ - v sin θ, y = u sin θ + v cos θ y simplifica."""
    sustitucion = {x: u*sp.cos(theta) - v*sp.sin(theta),
                   y: u*sp.sin(theta) + v*sp.cos(theta)}
    return sp.expand(sp.simplify(expresion.subs(sustitucion, simultaneous=True)))


def matriz_rotacion(theta):
    """Matriz de rotación de NumPy (2 × 2) para un ángulo theta en radianes."""
    t = float(theta)
    return np.array([[np.cos(t), -np.sin(t)],
                     [np.sin(t),  np.cos(t)]])


def plano_cartesiano(ax, limite=3):
    """Prepara ax como plano cartesiano: ejes en el origen, misma escala y cuadrícula."""
    ax.axhline(0, color="black", linewidth=0.8)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_xlim(-limite, limite)
    ax.set_ylim(-limite, limite)
    ax.set_aspect("equal")
    ax.grid(True, alpha=0.3)

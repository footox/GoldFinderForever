# Genera GoldFinderGuides.lua: lista propia de subida 1-300 por profesion (que fabricar por tramo, como se
# aprende cada receta y zonas de recoleccion). Uso:  python -I tools/gen_guides.py <carpeta_wago_data>
# Fuentes: tablas publicas del juego en wago.tools (SkillLineAbility, SpellReagents, SpellEffect, SpellName,
# Item, ItemSparse) y los hechos ya incluidos en el addon (GoldFinderRoutes.lua: pasos y zonas de Icy Veins).
# No usa datos de Zygor ni de ningun otro addon. Los CSV no se guardan en el repositorio (tools/wago_data/).
#
# Reglas:
# - Adquisicion: una receta se aprende con objeto si un objeto de ItemSparse llamado "Pattern: X", "Recipe: X",
#   "Plans: X", "Schematic: X", "Formula: X" o "Manual: X" de la misma profesion (RequiredSkill) ensena X; su
#   habilidad requerida es la del objeto (RequiredSkillRank, exacta). AcquireMethod = 1 en SkillLineAbility es una
#   receta que se aprende con la profesion (habilidad 1, exacta). Sin objeto, una receta de hechizo >= 21000
#   (parches tardios: reputacion, misiones, botin) o que fabrica un objeto raro o mejor (OverallQualityID >= 3)
#   tiene origen desconocido (l = "u"). El resto se supone del instructor. Las recetas de contenido nuevo
#   (hechizo >= 400000 u objeto de receta >= 200000: Season of Discovery / WoW Forever) no se usan.
# - Habilidad requerida de las recetas del instructor: las tablas no la tienen. Se estima como
#   max(1, y - d), con d = mediana de (y - habilidad requerida) de las recetas con objeto de esa profesion
#   (calibrado con los datos; p.ej. Peleteria 20, Cocina 40). Se marca approx: en el juego manda lo que anota
#   GoldFinder al visitar al instructor (GoldFinderDB.trainerRecipes).
# - Tramos: voraz punto a punto con las recetas del instructor (si no hay ninguna, las de objeto): menor coste
#   por punto esperado = coste de materiales / (probabilidad de subir x puntos por fabricacion). El coste usa el
#   precio de venta al vendedor (SellPrice) como referencia neutra; los precios reales los aplica el planificador
#   en el juego. Se mantiene la receta actual mientras siga naranja/amarilla y no cueste mas de un 30 % sobre la
#   mejor, para que los tramos sean largos. Una receta de objeto bastante mas barata se anota como opcional.
# - Peleteria 1-225: los pasos de Icy Veins de GoldFinderRoutes.lua (hechos ya incluidos en el addon).
# - Recoleccion (Mineria, Herboristeria, Desuello): zonas por tramo de GoldFinderRoutes.lua.
import csv, os, re, statistics, sys

if len(sys.argv) < 2:
    sys.exit("uso: python -I tools/gen_guides.py <carpeta_wago_data>")
D = sys.argv[1]
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "GoldFinderGuides.lua")
ROUTES = os.path.join(BASE, "GoldFinderRoutes.lua")
B = chr(92)

CRAFT = {"165": "Leatherworking", "197": "Tailoring", "164": "Blacksmithing", "171": "Alchemy",
         "202": "Engineering", "333": "Enchanting", "185": "Cooking", "129": "First Aid"}
GATHER = {"186": ("Mining", "mining"), "182": ("Herbalism", "herbalism"), "393": ("Skinning", "skinning"),
          "356": ("Fishing", "fishing")}
PREFIX = ("Pattern: ", "Recipe: ", "Plans: ", "Schematic: ", "Formula: ", "Manual: ")
STICK = 1.30       # se mantiene la receta actual si no cuesta mas de esto sobre la mejor
MAX_SPAN = 30      # tras tantos puntos con la misma receta, si ya es verde se prefiere otra naranja o amarilla
OPT_RATIO = 0.5    # una receta de objeto que cueste menos de esto frente a la elegida se anota como opcional
LATE_SPELL = 21000 # recetas de parches tardios (reputacion, misiones, botin) sin objeto conocido: origen desconocido
NO_PRICE = 5000
NEW_SPELL = 400000 # hechizos de contenido nuevo (SoD, WoW Forever): no se usan, no se sabe como se aprenden
NEW_ITEM = 200000  # objetos de receta de contenido nuevo: tampoco
MIN_BAND = 3       # un tramo de menos puntos se une al anterior si su receta aun sube    # coste (cobre) de un material sin precio de vendedor: se evita


def rows(name):
    with open(os.path.join(D, name + ".csv"), encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def num(v, default=0):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return default


names = {r["ID"]: r["Name_lang"] for r in rows("SpellName")}
reagents = {}
for r in rows("SpellReagents"):
    lst = []
    for i in range(8):
        item, cnt = num(r.get("Reagent_%d" % i)), num(r.get("ReagentCount_%d" % i))
        if item > 0 and cnt > 0:
            lst.append((item, cnt))
    if lst:
        reagents[r["SpellID"]] = lst

# efecto "crear objeto" (24): objeto producido
output = {}
for e in rows("SpellEffect"):
    if e["Effect"] == "24" and num(e["EffectItemType"]) > 0:
        output.setdefault(e["SpellID"], num(e["EffectItemType"]))

recipe_class = {r["ID"] for r in rows("Item") if r["ClassID"] == "9"}   # clase 9 = receta
sparse = {}
recipe_items = {}   # nombre de la receta -> [(objeto, habilidad requerida)]
for r in rows("ItemSparse"):
    sparse[r["ID"]] = r
    n = r["Display_lang"]
    if n.startswith(PREFIX) and r["ID"] in recipe_class and int(r["ID"]) < NEW_ITEM:
        # RequiredSkill no siempre es la linea de la receta (Primeros auxilios usa 2942): se compara por nombre
        recipe_items.setdefault(n.split(": ", 1)[1].strip(), []).append((int(r["ID"]), num(r["RequiredSkillRank"])))


def name_key(n):
    # nombre flexible: "Mithril Head Trout" (libro) = "Mithril Headed Trout" (receta); plurales iguales
    out = []
    for w in re.findall(r"[a-z]+", n.lower()):
        if len(w) > 4 and w.endswith("ed"):
            w = w[:-2]
        if len(w) > 3 and w.endswith("s"):
            w = w[:-1]
        out.append(w)
    return " ".join(out)


recipe_items_loose = {}
for k, v in recipe_items.items():
    recipe_items_loose.setdefault(name_key(k), []).extend(v)


def unit_cost(item):
    s = sparse.get(str(item))
    if not s:
        return NO_PRICE
    sell, buy = num(s["SellPrice"]), num(s["BuyPrice"])
    v = max(sell, buy // 4)
    return v if v > 0 else NO_PRICE


# recetas por linea (mismo criterio que gen_recipes.py: con materiales y umbrales de color)
recipes = {}
for r in rows("SkillLineAbility"):
    line = r["SkillLine"]
    if line not in CRAFT:
        continue
    sp = r["Spell"]
    low, high = num(r["TrivialSkillLineRankLow"]), num(r["TrivialSkillLineRankHigh"])
    if sp not in reagents or high <= 0 or high <= low:
        continue
    n = names.get(sp, "")
    if not n or n.lower().startswith(("test", "[dnd]", "zz", "deprecated", "old ")):
        continue
    if int(sp) >= NEW_SPELL:   # contenido nuevo (Season of Discovery / WoW Forever): origen sin datos
        continue
    lst = recipes.setdefault(line, {})
    if n in lst:      # mismo nombre (otra faccion o rango): se queda la primera
        continue
    x = {"sp": int(sp), "n": n, "y": low, "g": high, "k": max(1, num(r["NumSkillUps"], 1)),
         "r": reagents[sp], "acq": r["AcquireMethod"], "o": output.get(sp)}
    it = recipe_items.get(n) or recipe_items_loose.get(name_key(n))
    if it:
        x["learn"], x["item"], x["req"] = "item", min(it, key=lambda t: t[1])[0], min(t[1] for t in it)
    x["cost"] = sum(unit_cost(i) * c for i, c in x["r"])
    lst[n] = x

# calibracion: diferencia entre amarilla y habilidad requerida en las recetas de objeto
# (con menos de 5 recetas de objeto en la profesion se usa la mediana de todas)
offset, alld = {}, []
for line, lst in recipes.items():
    d = [x["y"] - x["req"] for x in lst.values() if x.get("learn") == "item" and x["req"] > 0]
    alld += d
    offset[line] = int(statistics.median(d)) if len(d) >= 5 else None
for line in offset:
    if offset[line] is None:
        offset[line] = int(statistics.median(alld))
for line, lst in recipes.items():
    for x in lst.values():
        if x.get("learn"):
            continue
        out = sparse.get(str(x["o"])) if x["o"] else None
        if x["acq"] == "1":
            x["learn"], x["req"], x["approx"] = "trainer", 1, False
        elif x["sp"] >= LATE_SPELL or (out and num(out["OverallQualityID"]) >= 3):
            x["learn"], x["req"], x["approx"] = "unknown", max(1, x["y"] - offset[line]), True
        else:
            x["learn"], x["req"], x["approx"] = "trainer", max(1, x["y"] - offset[line]), True


def chance(x, s):
    if s < x["y"]:
        return 1.0
    return max(0.0, (x["g"] - s) / (x["g"] - x["y"]))


def per_point(x, s):
    p = chance(x, s)
    return x["cost"] / (p * x["k"]) if p > 0 else None


def usable(x, s):
    return x["req"] <= s and chance(x, s) > 0


def greedy(line, start, top, bands):
    lst = list(recipes[line].values())
    cur, cur_from = None, start
    s = start
    while s < top:
        pool = [x for x in lst if x["learn"] == "trainer" and usable(x, s)]
        if not pool:
            pool = [x for x in lst if x["learn"] == "item" and usable(x, s)]
        if not pool:
            pool = [x for x in lst if usable(x, s)]
        # la receta actual sigue siendo candidata aunque sea de libro (si no, se volveria a la del instructor
        # al punto siguiente y el cambio desapareceria al unir tramos)
        if cur and cur not in pool and usable(cur, s):
            pool.append(cur)
        if not pool:
            add_point(bands, None, s)
            s += 1
            continue
        # una receta ya verde tras MAX_SPAN puntos cede si hay otra que aun da puntos seguros (naranja o amarilla)
        # (tambien recetas de libro: en Cocina casi todas se compran al vendedor)
        if cur and s - cur_from >= MAX_SPAN and chance(cur, s) < 0.75:
            fresh = [x for x in lst if x is not cur and x["learn"] in ("trainer", "item")
                     and usable(x, s) and chance(x, s) >= 0.75]
            if fresh:
                pool = fresh
        best = min(pool, key=lambda x: (per_point(x, s), -x["g"], x["sp"]))
        if cur and cur in pool and s < (cur["y"] + cur["g"]) / 2 and per_point(cur, s) <= per_point(best, s) * STICK:
            best = cur
        if best is not cur:
            cur_from = s
        cur = best
        add_point(bands, best, s)
        s += 1


def add_point(bands, x, s):
    p = chance(x, s) if x else 0
    crafts = 1 / (p * x["k"]) if x else 0
    last = bands[-1] if bands else None
    if last and last["x"] is x and last["to"] == s:
        last["to"] = s + 1
        last["crafts"] += crafts
    else:
        bands.append({"from": s, "to": s + 1, "x": x, "crafts": crafts})


def merge_small(bands):
    out = []
    for b in bands:
        last = out[-1] if out else None
        x = last and last["x"]
        if (last and not b.get("icy") and not last.get("icy") and b["to"] - b["from"] < MIN_BAND and x
                and all(chance(x, s) > 0 for s in range(b["from"], b["to"]))):
            last["to"] = b["to"]
            last["crafts"] += sum(1 / (chance(x, s) * x["k"]) for s in range(b["from"], b["to"]))
        elif last and x is not None and last["x"] is b["x"] and last["to"] == b["from"] and not b.get("icy"):
            last["to"] = b["to"]
            last["crafts"] += b["crafts"]
        else:
            out.append(b)
    return out


def optional(line, b):
    """Receta de objeto bastante mas barata para el tramo (opcional)."""
    x = b["x"]
    if not x:
        return None
    s = b["from"]
    pp = per_point(x, s)
    best = None
    for o in recipes[line].values():
        if o["learn"] != "item" or o is x or not usable(o, s) or chance(o, b["to"] - 1) <= 0:
            continue
        op = per_point(o, s)
        if op is not None and op < pp * OPT_RATIO and (not best or op < per_point(best, s)):
            best = o
    return best


# Pasos de Peleteria de Icy Veins (GoldFinderRoutes.lua) y zonas de recoleccion
routes_src = open(ROUTES, encoding="utf-8").read()


def route_block(key):
    m = re.search(r"\n  %s = \{(.*?)\n  \},?\n" % key, routes_src, re.S)
    return m.group(1) if m else ""


icy_lw = []
for m in re.finditer(r'\{ from = (\d+),\s*to = (\d+),\s*what = "([^"]+)"', route_block("leatherworking")):
    f, t, w = int(m.group(1)), int(m.group(2)), m.group(3)
    if t > f:
        icy_lw.append((f, t, w))


def zones(key):
    out = []
    for m in re.finditer(r'\{ from = (\d+),\s*to = (\d+),\s*zone = "([^"]+)", note = "([^"]*)" \}', route_block(key)):
        out.append((int(m.group(1)), int(m.group(2)), m.group(3), m.group(4)))
    return out


def lua_str(v):
    return '"' + v.replace(B, B + B).replace('"', B + '"').replace("\n", " ") + '"'


L = []
L.append("-- GoldFinderGuides: lista propia de subida de profesion 1-300 (que fabricar por tramo y como se aprende cada")
L.append("-- receta; zonas por tramo en recoleccion). Generado por tools/gen_guides.py. Fuentes: tablas publicas del")
L.append("-- juego en wago.tools (SkillLineAbility, SpellReagents, SpellEffect, SpellName, Item, ItemSparse) y los hechos")
L.append("-- de GoldFinderRoutes (guias de Icy Veins: pasos de Peleteria 1-225 y zonas de recoleccion).")
L.append("-- No contiene datos de Zygor ni de ningun otro addon.")
L.append("-- Tramo: f/t = habilidad desde/hasta, s = hechizo de la receta (materiales en GoldFinderRecipes), n = nombre,")
L.append("-- c = fabricaciones estimadas, l = como se aprende (t instructor, i objeto de receta, u desconocido),")
L.append("-- i = objeto de la receta, q = habilidad requerida, a = true si q es estimada (instructor; manda lo que se")
L.append("-- anota al visitarlo), src = \"icy\" si el paso es de Icy Veins, o/on = receta de objeto opcional mas barata.")
L.append("-- Recoleccion: zones = { {f, t, zona, nota} }. El coste es una referencia (precio del vendedor), no la subasta.")
L.append("GoldFinderGuides = {")
summary = []
for line in ["165", "197", "164", "171", "202", "333", "185", "129"]:
    prof = CRAFT[line]
    bands = []
    start = 1
    if line == "165":
        byname = recipes[line]
        for f, t, w in icy_lw:
            x = byname.get(w)
            if not x or f < start:
                continue
            if x["learn"] == "unknown":   # paso de Icy Veins: se aprende con el instructor
                x["learn"] = "trainer"
            if f > start:
                greedy(line, start, f, bands)
            crafts = sum(1 / (chance(x, s) * x["k"]) if chance(x, s) > 0 else 1 for s in range(f, t))
            bands.append({"from": f, "to": t, "x": x, "crafts": crafts, "icy": True})
            start = t
    greedy(line, start, 300, bands)
    bands = merge_small(bands)
    L.append("  [%s] = { name = %s, line = %s, bands = {" % (lua_str(prof.lower()), lua_str(prof), line))
    nb = 0
    for b in bands:
        x = b["x"]
        if not x:
            L.append("    { f = %d, t = %d, l = \"u\" }," % (b["from"], b["to"]))
            nb += 1
            continue
        parts = ["f = %d" % b["from"], "t = %d" % b["to"], "s = %d" % x["sp"], "n = %s" % lua_str(x["n"]),
                 "c = %d" % max(1, round(b["crafts"]))]
        if x["learn"] == "item":
            parts += ["l = \"i\"", "i = %d" % x["item"], "q = %d" % x["req"]]
        elif x["learn"] == "unknown":
            parts += ["l = \"u\"", "q = %d" % x["req"], "a = true"]
        else:
            parts += ["l = \"t\"", "q = %d" % x["req"]]
            if x.get("approx"):
                parts.append("a = true")
        if b.get("icy"):
            parts.append('src = "icy"')
        o = optional(line, b)
        if o:
            parts += ["o = %d" % o["item"], "on = %s" % lua_str(o["n"])]
        L.append("    { %s }," % ", ".join(parts))
        nb += 1
    L.append("  } },")
    summary.append("%s %d tramos (desfase instructor %d)" % (prof, nb, offset[line]))
for line, (prof, key) in GATHER.items():
    z = zones(key)
    if not z:
        summary.append("%s sin zonas" % prof)
        continue
    L.append("  [%s] = { name = %s, line = %s, zones = {" % (lua_str(prof.lower()), lua_str(prof), line))
    for f, t, zone, note in z:
        L.append("    { %d, %d, %s, %s }," % (f, t, lua_str(zone), lua_str(note)))
    L.append("  } },")
    summary.append("%s %d zonas" % (prof, len(z)))
L.append("}")
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(L) + "\n")
for s in summary:
    print(s)
print("archivo:", OUT, os.path.getsize(OUT), "bytes")

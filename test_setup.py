import sys
print(f"Python: {sys.executable}")
print(f"Version: {sys.version}")

try:
    import flask
    print("✅ Flask installé")
except:
    print("❌ Flask manquant")

try:
    import psycopg2
    print("✅ psycopg2 installé")
except:
    print("❌ psycopg2 manquant")
    sys.exit(1)

try:
    conn = psycopg2.connect(
        host="localhost",
        database="colonie",
        user="postgres",
        password="password"
    )
    cur = conn.cursor()
    cur.execute("select count(*) from robots")
    count = cur.fetchone()[0]
    print(f"✅ Connexion BD OK - {count} robots trouvés")
    cur.close()
    conn.close()
except Exception as e:
    print(f"❌ Erreur BD: {e}")
    sys.exit(1)

print("\n✅ Tous les tests passent - Prêt à lancer l'app!")

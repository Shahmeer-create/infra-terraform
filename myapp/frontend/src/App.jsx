import React, { useState, useEffect, useRef } from "react";
import {
  getHealth, getUsers, createUser, deleteUser,
  getPhotos, uploadPhoto, getPhotoUrl, deletePhoto
} from "./api.js";

const TABS = ["Health", "Users", "Photos"];

export default function App() {
  const [tab, setTab] = useState("Health");

  return (
    <div style={styles.container}>
      <header style={styles.header}>
        <h1 style={styles.title}>MyApp</h1>
        <p style={styles.subtitle}>Frontend (Amplify) + Backend (ECS) + RDS + S3</p>
      </header>

      <nav style={styles.nav}>
        {TABS.map(t => (
          <button
            key={t}
            onClick={() => setTab(t)}
            style={tab === t ? { ...styles.tab, ...styles.tabActive } : styles.tab}
          >
            {t}
          </button>
        ))}
      </nav>

      <main style={styles.main}>
        {tab === "Health" && <HealthPanel />}
        {tab === "Users" && <UsersPanel />}
        {tab === "Photos" && <PhotosPanel />}
      </main>
    </div>
  );
}

/* ===================== HEALTH PANEL ===================== */
function HealthPanel() {
  const [health, setHealth] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  async function check() {
    setLoading(true);
    setError(null);
    try {
      const data = await getHealth();
      setHealth(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { check(); }, []);

  return (
    <div>
      <div style={styles.sectionHeader}>
        <h2>System Health</h2>
        <button onClick={check} style={styles.btn}>Refresh</button>
      </div>
      {loading && <p>Checking...</p>}
      {error && <p style={styles.error}>Cannot reach backend: {error}</p>}
      {health && (
        <div style={styles.card}>
          <StatusRow label="Backend API" value={health.status} />
          <StatusRow label="MySQL Database" value={health.database} />
          <StatusRow label="S3 Photos Bucket" value={health.s3} />
          <p style={styles.muted}>Last checked: {health.timestamp}</p>
        </div>
      )}
    </div>
  );
}

function StatusRow({ label, value }) {
  const ok = value === "ok" || value === "connected" || value === "accessible";
  return (
    <div style={styles.statusRow}>
      <span>{label}</span>
      <span style={{ color: ok ? "#16a34a" : "#dc2626", fontWeight: 600 }}>
        {ok ? "Connected" : value || "Unknown"}
      </span>
    </div>
  );
}

/* ===================== USERS PANEL ===================== */
function UsersPanel() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");

  async function load() {
    setLoading(true);
    try {
      const data = await getUsers();
      setUsers(data.users);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  async function handleCreate(e) {
    e.preventDefault();
    if (!name.trim() || !email.trim()) return;
    try {
      await createUser(name.trim(), email.trim());
      setName("");
      setEmail("");
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleDelete(id) {
    try {
      await deleteUser(id);
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div>
      <h2>Users</h2>
      {error && <p style={styles.error}>{error}</p>}

      <div style={styles.card}>
        <h3 style={{ marginTop: 0 }}>Add User</h3>
        <div style={styles.formRow}>
          <input style={styles.input} placeholder="Name" value={name} onChange={e => setName(e.target.value)} />
          <input style={styles.input} placeholder="Email" value={email} onChange={e => setEmail(e.target.value)} />
          <button style={styles.btn} onClick={handleCreate}>Add</button>
        </div>
      </div>

      {loading ? <p>Loading...</p> : (
        <div style={styles.card}>
          <h3 style={{ marginTop: 0 }}>All Users ({users.length})</h3>
          {users.length === 0 ? (
            <p style={styles.muted}>No users yet. Add one above.</p>
          ) : (
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>ID</th>
                  <th style={styles.th}>Name</th>
                  <th style={styles.th}>Email</th>
                  <th style={styles.th}>Created</th>
                  <th style={styles.th}></th>
                </tr>
              </thead>
              <tbody>
                {users.map(u => (
                  <tr key={u.id}>
                    <td style={styles.td}>{u.id}</td>
                    <td style={styles.td}>{u.name}</td>
                    <td style={styles.td}>{u.email}</td>
                    <td style={styles.td}>{new Date(u.created_at).toLocaleDateString()}</td>
                    <td style={styles.td}>
                      <button style={styles.btnDanger} onClick={() => handleDelete(u.id)}>Delete</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}

/* ===================== PHOTOS PANEL ===================== */
function PhotosPanel() {
  const [photos, setPhotos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [userId, setUserId] = useState("1");
  const [uploading, setUploading] = useState(false);
  const fileRef = useRef(null);

  async function load() {
    setLoading(true);
    try {
      const data = await getPhotos();
      setPhotos(data.photos);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  async function handleUpload() {
    const file = fileRef.current?.files?.[0];
    if (!file || !userId.trim()) return;
    setUploading(true);
    setError(null);
    try {
      await uploadPhoto(userId.trim(), file);
      fileRef.current.value = "";
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      setUploading(false);
    }
  }

  async function handleView(id) {
    try {
      const data = await getPhotoUrl(id);
      window.open(data.url, "_blank");
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleDelete(id) {
    try {
      await deletePhoto(id);
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div>
      <h2>Photos (stored in S3)</h2>
      {error && <p style={styles.error}>{error}</p>}

      <div style={styles.card}>
        <h3 style={{ marginTop: 0 }}>Upload Photo</h3>
        <div style={styles.formRow}>
          <input style={styles.input} placeholder="User ID" value={userId} onChange={e => setUserId(e.target.value)} />
          <input type="file" accept="image/*" ref={fileRef} style={styles.input} />
          <button style={styles.btn} onClick={handleUpload} disabled={uploading}>
            {uploading ? "Uploading..." : "Upload"}
          </button>
        </div>
      </div>

      {loading ? <p>Loading...</p> : (
        <div style={styles.card}>
          <h3 style={{ marginTop: 0 }}>All Photos ({photos.length})</h3>
          {photos.length === 0 ? (
            <p style={styles.muted}>No photos yet. Upload one above.</p>
          ) : (
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>ID</th>
                  <th style={styles.th}>User</th>
                  <th style={styles.th}>Filename</th>
                  <th style={styles.th}>Size</th>
                  <th style={styles.th}>Uploaded</th>
                  <th style={styles.th}></th>
                </tr>
              </thead>
              <tbody>
                {photos.map(p => (
                  <tr key={p.id}>
                    <td style={styles.td}>{p.id}</td>
                    <td style={styles.td}>{p.user_id}</td>
                    <td style={styles.td}>{p.filename}</td>
                    <td style={styles.td}>{(p.size_bytes / 1024).toFixed(1)} KB</td>
                    <td style={styles.td}>{new Date(p.created_at).toLocaleDateString()}</td>
                    <td style={styles.td}>
                      <button style={styles.btn} onClick={() => handleView(p.id)}>View</button>
                      {" "}
                      <button style={styles.btnDanger} onClick={() => handleDelete(p.id)}>Delete</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}

/* ===================== STYLES ===================== */
const styles = {
  container: { maxWidth: 900, margin: "0 auto", padding: 20, fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" },
  header: { textAlign: "center", marginBottom: 20 },
  title: { margin: 0, fontSize: 28 },
  subtitle: { margin: "4px 0 0", color: "#666", fontSize: 14 },
  nav: { display: "flex", gap: 8, marginBottom: 24, borderBottom: "2px solid #e5e7eb", paddingBottom: 8 },
  tab: { padding: "8px 20px", border: "none", background: "none", cursor: "pointer", fontSize: 15, borderRadius: "6px 6px 0 0", color: "#666" },
  tabActive: { background: "#2563eb", color: "#fff" },
  main: {},
  card: { background: "#f9fafb", border: "1px solid #e5e7eb", borderRadius: 8, padding: 20, marginBottom: 16 },
  sectionHeader: { display: "flex", justifyContent: "space-between", alignItems: "center" },
  statusRow: { display: "flex", justifyContent: "space-between", padding: "10px 0", borderBottom: "1px solid #e5e7eb" },
  formRow: { display: "flex", gap: 8, flexWrap: "wrap" },
  input: { padding: "8px 12px", border: "1px solid #d1d5db", borderRadius: 6, fontSize: 14 },
  btn: { padding: "8px 16px", background: "#2563eb", color: "#fff", border: "none", borderRadius: 6, cursor: "pointer", fontSize: 14 },
  btnDanger: { padding: "6px 12px", background: "#dc2626", color: "#fff", border: "none", borderRadius: 6, cursor: "pointer", fontSize: 13 },
  table: { width: "100%", borderCollapse: "collapse" },
  th: { textAlign: "left", padding: "8px 12px", borderBottom: "2px solid #e5e7eb", fontSize: 13, color: "#666" },
  td: { padding: "8px 12px", borderBottom: "1px solid #e5e7eb", fontSize: 14 },
  error: { color: "#dc2626", background: "#fef2f2", padding: "8px 12px", borderRadius: 6, border: "1px solid #fecaca" },
  muted: { color: "#999", fontSize: 13 }
};

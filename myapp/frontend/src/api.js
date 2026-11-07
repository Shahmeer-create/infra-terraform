// Amplify sets this env var at build time via Terraform
// During local dev, create a .env file with VITE_API_URL=http://localhost:3000
const API_URL = import.meta.env.VITE_API_URL || "http://localhost:3000";

async function request(path, options = {}) {
  const url = `${API_URL}${path}`;
  const res = await fetch(url, {
    headers: { "Content-Type": "application/json", ...options.headers },
    ...options
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error(err.error || "Request failed");
  }
  return res.json();
}

export async function getHealth() {
  return request("/health");
}

export async function getUsers() {
  return request("/api/users");
}

export async function createUser(name, email) {
  return request("/api/users", {
    method: "POST",
    body: JSON.stringify({ name, email })
  });
}

export async function deleteUser(id) {
  return request(`/api/users/${id}`, { method: "DELETE" });
}

export async function getPhotos() {
  return request("/api/photos");
}

export async function uploadPhoto(userId, file) {
  const formData = new FormData();
  formData.append("photo", file);
  formData.append("user_id", userId);

  const url = `${API_URL}/api/photos/upload`;
  const res = await fetch(url, { method: "POST", body: formData });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error(err.error || "Upload failed");
  }
  return res.json();
}

export async function getPhotoUrl(id) {
  return request(`/api/photos/${id}/url`);
}

export async function deletePhoto(id) {
  return request(`/api/photos/${id}`, { method: "DELETE" });
}

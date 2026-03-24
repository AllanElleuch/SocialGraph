import express from "express";
import { createServer as createViteServer } from "vite";
import path from "path";
import fs from "fs";

async function startServer() {
  const app = express();
  const PORT = 3000;

  app.use(express.json());

  const DATA_FILE = path.join(process.cwd(), "contacts.json");

  // Initial data if file doesn't exist
  if (!fs.existsSync(DATA_FILE)) {
    const initialData = [
      {
        id: "1",
        name: "Alice Johnson",
        tags: ["Tech", "Design"],
        locationMet: "San Francisco",
        lat: 37.7749,
        lng: -122.4194,
        dateMet: "2023-05-15T10:00:00Z",
        connections: ["2", "3"],
        lastInteraction: "2024-01-10T15:00:00Z"
      },
      {
        id: "2",
        name: "Bob Smith",
        tags: ["Engineering"],
        locationMet: "New York",
        lat: 40.7128,
        lng: -74.0060,
        dateMet: "2022-11-20T09:00:00Z",
        connections: ["1", "3"],
        lastInteraction: "2023-12-05T11:00:00Z"
      },
      {
        id: "3",
        name: "Charlie Brown",
        tags: ["Product"],
        locationMet: "San Francisco",
        lat: 37.7749,
        lng: -122.4194,
        dateMet: "2023-08-01T14:00:00Z",
        connections: ["1", "2"],
        lastInteraction: "2024-03-01T10:00:00Z"
      }
    ];
    fs.writeFileSync(DATA_FILE, JSON.stringify(initialData, null, 2));
  }

  // API routes
  app.get("/api/contacts", (req, res) => {
    const data = JSON.parse(fs.readFileSync(DATA_FILE, "utf-8"));
    res.json(data);
  });

  app.post("/api/contacts", (req, res) => {
    const data = JSON.parse(fs.readFileSync(DATA_FILE, "utf-8"));
    const newContact = { ...req.body, id: Date.now().toString() };
    data.push(newContact);
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
    res.json(newContact);
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), "dist");
    app.use(express.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(path.join(distPath, "index.html"));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();

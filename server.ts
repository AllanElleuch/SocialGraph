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
        lastInteraction: "2024-01-10T15:00:00Z",
        createdAt: "2024-01-01T10:00:00Z"
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
        lastInteraction: "2023-12-05T11:00:00Z",
        createdAt: "2024-01-02T10:00:00Z"
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
        lastInteraction: "2024-03-01T10:00:00Z",
        createdAt: "2024-01-03T10:00:00Z"
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
    const newContact = { ...req.body, id: Date.now().toString(), createdAt: new Date().toISOString() };
    
    // Add bidirectional connections
    if (newContact.connections && Array.isArray(newContact.connections)) {
      newContact.connections.forEach((connId: string) => {
        const target = data.find((c: any) => c.id === connId);
        if (target && !target.connections.includes(newContact.id)) {
          target.connections.push(newContact.id);
        }
      });
    }

    data.push(newContact);
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
    res.json(newContact);
  });

  app.put("/api/contacts/:id", (req, res) => {
    const data = JSON.parse(fs.readFileSync(DATA_FILE, "utf-8"));
    const index = data.findIndex((c: any) => c.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: "Contact not found" });
    }
    
    const oldContact = data[index];
    const updatedContact = { ...oldContact, ...req.body };
    
    // Handle bidirectional connections
    const oldConns = oldContact.connections || [];
    const newConns = updatedContact.connections || [];
    
    // Remove from contacts that are no longer connected
    oldConns.forEach((connId: string) => {
      if (!newConns.includes(connId)) {
        const target = data.find((c: any) => c.id === connId);
        if (target) {
          target.connections = target.connections.filter((id: string) => id !== updatedContact.id);
        }
      }
    });
    
    // Add to new connections
    newConns.forEach((connId: string) => {
      if (!oldConns.includes(connId)) {
        const target = data.find((c: any) => c.id === connId);
        if (target && !target.connections.includes(updatedContact.id)) {
          target.connections.push(updatedContact.id);
        }
      }
    });

    data[index] = updatedContact;
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
    res.json(updatedContact);
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

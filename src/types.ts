export interface Contact {
  id: string;
  name: string;
  tags: string[];
  locationMet: string;
  lat?: number;
  lng?: number;
  dateMet: string; // ISO string
  connections: string[]; // Array of contact IDs
  lastInteraction?: string; // ISO string
}

export interface GraphNode extends d3.SimulationNodeDatum {
  id: string;
  name: string;
  type: 'contact';
  data: Contact;
}

export interface GraphLink extends d3.SimulationLinkDatum<GraphNode> {
  source: string | GraphNode;
  target: string | GraphNode;
  type: 'connection' | 'location' | 'time';
}

export type PivotType = 'mutual' | 'location' | 'time';

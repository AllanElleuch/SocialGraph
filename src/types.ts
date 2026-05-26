export interface Contact {
  id: string;
  firstName: string;
  lastName: string;
  workplace?: string;
  homeAddress?: string;
  tags: string[];
  locationMet: string;
  lat?: number;
  lng?: number;
  dateMet: string; // ISO string
  connections: string[]; // Array of contact IDs
  lastInteraction?: string; // ISO string
  birthday?: string; // ISO string
  email?: string;
  address?: string;
  addressLat?: number;
  addressLng?: number;
  createdAt?: string; // ISO string
}

/** Full display name for a contact, tolerant of missing parts. */
export function getFullName(contact: Pick<Contact, 'firstName' | 'lastName'>): string {
  return [contact.firstName, contact.lastName].filter(Boolean).join(' ').trim();
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

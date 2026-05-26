import React, { useState, useEffect } from 'react';
import { Contact, PivotType } from './types';
import Graph from './components/Graph';
import LocationMap from './components/LocationMap';
import ContactCard from './components/ContactCard';
import Controls from './components/Controls';
import AddContactModal from './components/AddContactModal';
import { motion, AnimatePresence } from 'motion/react';
import { Search, Info } from 'lucide-react';

export default function App() {
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [pivot, setPivot] = useState<PivotType>('mutual');
  const [selectedContact, setSelectedContact] = useState<Contact | null>(null);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [editingContact, setEditingContact] = useState<Contact | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchContacts();
  }, []);

  const fetchContacts = async () => {
    try {
      const res = await fetch('/api/contacts');
      const data = await res.json();
      setContacts(data);
    } catch (err) {
      console.error('Failed to fetch contacts:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleAddContact = async (newContact: Partial<Contact>) => {
    try {
      const res = await fetch('/api/contacts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newContact),
      });
      if (res.ok) {
        await fetchContacts();
      }
    } catch (err) {
      console.error('Failed to add contact:', err);
    }
  };

  const handleEditContact = async (updatedContact: Partial<Contact>) => {
    if (!editingContact) return;
    try {
      const res = await fetch(`/api/contacts/${editingContact.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updatedContact),
      });
      if (res.ok) {
        await fetchContacts();
        const updated = await res.json();
        if (selectedContact?.id === updated.id) {
          setSelectedContact(updated);
        }
      }
    } catch (err) {
      console.error('Failed to edit contact:', err);
    }
  };

  const filteredContacts = contacts.filter(c => 
    c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    c.tags.some(t => t.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  return (
    <div className="relative w-full h-screen bg-[#020617] text-slate-200 font-sans overflow-hidden">
      {/* Header */}
      <header className="absolute top-0 left-0 w-full p-4 md:p-6 flex flex-col md:flex-row justify-between items-start md:items-center gap-4 z-30 pointer-events-none">
        <div className="pointer-events-auto">
          <h1 className="text-lg md:text-xl font-bold tracking-tighter text-white flex items-center gap-2">
            <div className="w-2 h-2 bg-indigo-500 rounded-full animate-pulse" />
            CONTEXTUAL CONTACTS
          </h1>
          <p className="text-[10px] uppercase tracking-[0.2em] text-gray-500 mt-1">Graph-Based Network Explorer</p>
          
          {/* Legend / Status */}
          <div className="mt-4 bg-[#1a1a1a]/50 backdrop-blur-sm p-3 rounded-xl border border-[#333]/50 w-fit hidden sm:block">
            <div className="text-[9px] uppercase tracking-widest text-gray-500 mb-1">Active View</div>
            <div className="text-xs font-medium text-white capitalize">{pivot} Clustering</div>
            <div className="mt-3 flex flex-col gap-1.5">
              <div className="flex items-center gap-2">
                <div className="w-1.5 h-1.5 rounded-full bg-indigo-500" />
                <span className="text-[9px] text-gray-400">Contact Node</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-[1px] bg-gray-600" />
                <span className="text-[9px] text-gray-400">Relationship</span>
              </div>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2 md:gap-4 pointer-events-auto w-full md:w-auto">
          <div className="relative flex-1 md:flex-none">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500" size={16} />
            <input 
              type="text"
              placeholder="Search network..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="bg-[#1a1a1a] border border-[#333] rounded-full py-2 pl-10 pr-4 text-sm focus:outline-none focus:border-indigo-500 transition-all w-full md:w-64"
            />
          </div>
          <button className="p-2 text-gray-500 hover:text-white transition-colors shrink-0">
            <Info size={20} />
          </button>
        </div>
      </header>

      {/* Main Graph Area */}
      <main className="w-full h-full">
        {loading ? (
          <div className="w-full h-full flex items-center justify-center">
            <div className="w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : pivot === 'location' ? (
          <LocationMap 
            contacts={filteredContacts} 
            onSelectContact={setSelectedContact} 
          />
        ) : (
          <Graph 
            contacts={filteredContacts} 
            pivot={pivot} 
            onSelectContact={setSelectedContact} 
          />
        )}
      </main>

      {/* UI Overlays */}
      <Controls 
        pivot={pivot} 
        setPivot={setPivot} 
        onAddContact={() => setIsAddModalOpen(true)} 
      />

      <ContactCard 
        contact={selectedContact} 
        onClose={() => setSelectedContact(null)} 
        onEdit={(contact) => setEditingContact(contact)}
      />

      <AddContactModal 
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        onAdd={handleAddContact}
        existingContacts={contacts}
      />

      {editingContact && (
        <AddContactModal 
          isOpen={!!editingContact}
          onClose={() => setEditingContact(null)}
          onAdd={handleEditContact}
          existingContacts={contacts}
          initialContact={editingContact}
        />
      )}

    </div>
  );
}

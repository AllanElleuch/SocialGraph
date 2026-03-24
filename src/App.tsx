import React, { useState, useEffect } from 'react';
import { Contact, PivotType } from './types';
import Graph from './components/Graph';
import ContactCard from './components/ContactCard';
import Controls from './components/Controls';
import { motion, AnimatePresence } from 'motion/react';
import { Search, Info } from 'lucide-react';

export default function App() {
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [pivot, setPivot] = useState<PivotType>('mutual');
  const [selectedContact, setSelectedContact] = useState<Contact | null>(null);
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

  const filteredContacts = contacts.filter(c => 
    c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    c.tags.some(t => t.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  return (
    <div className="relative w-full h-screen bg-[#0a0a0a] text-slate-200 font-sans overflow-hidden">
      {/* Header */}
      <header className="absolute top-0 left-0 w-full p-6 flex justify-between items-center z-30 pointer-events-none">
        <div className="pointer-events-auto">
          <h1 className="text-xl font-bold tracking-tighter text-white flex items-center gap-2">
            <div className="w-2 h-2 bg-indigo-500 rounded-full animate-pulse" />
            CONTEXTUAL CONTACTS
          </h1>
          <p className="text-[10px] uppercase tracking-[0.2em] text-gray-500 mt-1">Graph-Based Network Explorer</p>
        </div>

        <div className="flex items-center gap-4 pointer-events-auto">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500" size={16} />
            <input 
              type="text"
              placeholder="Search network..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="bg-[#1a1a1a] border border-[#333] rounded-full py-2 pl-10 pr-4 text-sm focus:outline-none focus:border-indigo-500 transition-all w-64"
            />
          </div>
          <button className="p-2 text-gray-500 hover:text-white transition-colors">
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
        onAddContact={() => alert('Add contact functionality would go here!')} 
      />

      <ContactCard 
        contact={selectedContact} 
        onClose={() => setSelectedContact(null)} 
      />

      {/* Legend / Status */}
      <div className="absolute bottom-8 left-8 z-30 pointer-events-none">
        <div className="bg-[#1a1a1a]/50 backdrop-blur-sm p-4 rounded-xl border border-[#333]/50">
          <div className="text-[10px] uppercase tracking-widest text-gray-500 mb-2">Active View</div>
          <div className="text-sm font-medium text-white capitalize">{pivot} Clustering</div>
          <div className="mt-4 flex flex-col gap-2">
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-indigo-500" />
              <span className="text-[10px] text-gray-400">Contact Node</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-4 h-[1px] bg-gray-600" />
              <span className="text-[10px] text-gray-400">Relationship</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

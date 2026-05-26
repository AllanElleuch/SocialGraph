import React, { useState, useEffect } from 'react';
import { X, User, Tag, MapPin, Calendar, Link as LinkIcon, Search, Crosshair } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { Contact, getFullName } from '../types';
import { MapContainer, TileLayer, Marker, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Fix Leaflet's default icon path issues
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const contactIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-violet.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

const houseIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-gold.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

function MapEvents({ setLat, setLng, setLocation }: { setLat: (lat: number) => void, setLng: (lng: number) => void, setLocation: (loc: string) => void }) {
  useMapEvents({
    click: async (e) => {
      const { lat, lng } = e.latlng;
      setLat(lat);
      setLng(lng);
      try {
        const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`);
        const data = await res.json();
        if (data && data.display_name) {
          // Simplify the address
          const parts = data.display_name.split(', ');
          const shortAddress = parts.length > 3 ? `${parts[0]}, ${parts[parts.length - 3]}` : data.display_name;
          setLocation(shortAddress);
        } else {
          setLocation(`Location (${lat.toFixed(2)}, ${lng.toFixed(2)})`);
        }
      } catch (err) {
        setLocation(`Location (${lat.toFixed(2)}, ${lng.toFixed(2)})`);
      }
    },
  });
  return null;
}

function MapUpdater({ lat, lng }: { lat: number, lng: number }) {
  const map = useMapEvents({});
  useEffect(() => {
    map.setView([lat, lng], map.getZoom());
  }, [lat, lng, map]);
  return null;
}

interface AddContactModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAdd: (contact: Partial<Contact>) => Promise<void>;
  existingContacts: Contact[];
  initialContact?: Contact;
}

const TAG_COLORS = [
  'bg-indigo-500/20 text-indigo-400 border-indigo-500/30',
  'bg-emerald-500/20 text-emerald-400 border-emerald-500/30',
  'bg-amber-500/20 text-amber-400 border-amber-500/30',
  'bg-rose-500/20 text-rose-400 border-rose-500/30',
  'bg-sky-500/20 text-sky-400 border-sky-500/30',
  'bg-purple-500/20 text-purple-400 border-purple-500/30',
];

const getTagColor = (tag: string) => {
  const hash = tag.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
  return TAG_COLORS[hash % TAG_COLORS.length];
};

const AddContactModal: React.FC<AddContactModalProps> = ({ isOpen, onClose, onAdd, existingContacts, initialContact }) => {
  const [firstName, setFirstName] = useState(initialContact?.firstName || '');
  const [lastName, setLastName] = useState(initialContact?.lastName || '');
  const [tagInput, setTagInput] = useState('');
  const [tagsList, setTagsList] = useState<string[]>(initialContact?.tags || []);
  const [location, setLocation] = useState(initialContact?.locationMet || '');
  const [lat, setLat] = useState<number | undefined>(initialContact?.lat);
  const [lng, setLng] = useState<number | undefined>(initialContact?.lng);
  const [date, setDate] = useState(initialContact?.dateMet ? new Date(initialContact.dateMet).toISOString().split('T')[0] : new Date().toISOString().split('T')[0]);
  const [birthday, setBirthday] = useState(initialContact?.birthday ? new Date(initialContact.birthday).toISOString().split('T')[0] : '');
  const [email, setEmail] = useState(initialContact?.email || '');
  const [address, setAddress] = useState(initialContact?.address || '');
  const [workplace, setWorkplace] = useState(initialContact?.workplace || '');
  const [connectionSearch, setConnectionSearch] = useState('');
  const [selectedConnections, setSelectedConnections] = useState<string[]>(initialContact?.connections || []);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isLocating, setIsLocating] = useState(false);
  const [isLookingUpLocation, setIsLookingUpLocation] = useState(false);
  const [isLookingUpAddress, setIsLookingUpAddress] = useState(false);
  const [addressLat, setAddressLat] = useState<number | undefined>(initialContact?.addressLat);
  const [addressLng, setAddressLng] = useState<number | undefined>(initialContact?.addressLng);

  const [locationSuggestions, setLocationSuggestions] = useState<any[]>([]);
  const [addressSuggestions, setAddressSuggestions] = useState<any[]>([]);
  const [showLocationSuggestions, setShowLocationSuggestions] = useState(false);
  const [showAddressSuggestions, setShowAddressSuggestions] = useState(false);

  useEffect(() => {
    if (isOpen && initialContact) {
      setFirstName(initialContact.firstName || '');
      setLastName(initialContact.lastName || '');
      setTagsList(initialContact.tags);
      setLocation(initialContact.locationMet);
      setLat(initialContact.lat);
      setLng(initialContact.lng);
      setDate(new Date(initialContact.dateMet).toISOString().split('T')[0]);
      setBirthday(initialContact.birthday ? new Date(initialContact.birthday).toISOString().split('T')[0] : '');
      setEmail(initialContact.email || '');
      setAddress(initialContact.address || '');
      setAddressLat(initialContact.addressLat);
      setAddressLng(initialContact.addressLng);
      setWorkplace(initialContact.workplace || '');
      setSelectedConnections(initialContact.connections || []);
    } else if (isOpen && !initialContact) {
      setFirstName('');
      setLastName('');
      setTagInput('');
      setTagsList([]);
      setLocation('');
      setLat(undefined);
      setLng(undefined);
      setDate(new Date().toISOString().split('T')[0]);
      setBirthday('');
      setEmail('');
      setAddress('');
      setAddressLat(undefined);
      setAddressLng(undefined);
      setWorkplace('');
      setSelectedConnections([]);
      setConnectionSearch('');
    }
  }, [isOpen, initialContact]);

  useEffect(() => {
    const timer = setTimeout(async () => {
      if (location && showLocationSuggestions) {
        try {
          const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(location)}&limit=5`);
          const data = await res.json();
          setLocationSuggestions(data || []);
        } catch (err) {
          console.error(err);
        }
      } else {
        setLocationSuggestions([]);
      }
    }, 500);
    return () => clearTimeout(timer);
  }, [location, showLocationSuggestions]);

  useEffect(() => {
    const timer = setTimeout(async () => {
      if (address && showAddressSuggestions) {
        try {
          const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(address)}&limit=5`);
          const data = await res.json();
          setAddressSuggestions(data || []);
        } catch (err) {
          console.error(err);
        }
      } else {
        setAddressSuggestions([]);
      }
    }, 500);
    return () => clearTimeout(timer);
  }, [address, showAddressSuggestions]);

  const handleLookupLocation = async () => {
    if (!location) return;
    setIsLookingUpLocation(true);
    try {
      const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(location)}`);
      const data = await res.json();
      if (data && data.length > 0) {
        setLat(parseFloat(data[0].lat));
        setLng(parseFloat(data[0].lon));
      } else {
        alert('Location not found');
      }
    } catch (err) {
      console.error('Failed to geocode location:', err);
      alert('Failed to lookup location');
    } finally {
      setIsLookingUpLocation(false);
    }
  };

  const handleLookupAddress = async () => {
    if (!address) return;
    setIsLookingUpAddress(true);
    try {
      const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(address)}`);
      const data = await res.json();
      if (data && data.length > 0) {
        setAddressLat(parseFloat(data[0].lat));
        setAddressLng(parseFloat(data[0].lon));
      } else {
        alert('Address not found');
      }
    } catch (err) {
      console.error('Failed to geocode address:', err);
      alert('Failed to lookup address');
    } finally {
      setIsLookingUpAddress(false);
    }
  };

  const handleTagKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault();
      const newTag = tagInput.trim().replace(/,$/, '');
      if (newTag && !tagsList.includes(newTag)) {
        setTagsList([...tagsList, newTag]);
        setTagInput('');
      }
    } else if (e.key === 'Backspace' && !tagInput && tagsList.length > 0) {
      setTagsList(tagsList.slice(0, -1));
    }
  };

  const removeTag = (tagToRemove: string) => {
    setTagsList(tagsList.filter(t => t !== tagToRemove));
  };

  const handleUseGps = () => {
    if (!navigator.geolocation) {
      alert('Geolocation is not supported by your browser');
      return;
    }

    setIsLocating(true);
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        setLat(latitude);
        setLng(longitude);
        setLocation(`Current Location (${latitude.toFixed(2)}, ${longitude.toFixed(2)})`);
        setIsLocating(false);
      },
      (error) => {
        console.error('Error getting location:', error);
        alert('Could not get your location. Please check your permissions.');
        setIsLocating(false);
      }
    );
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    
    try {
      let addressLat: number | undefined = undefined;
      let addressLng: number | undefined = undefined;

      if (address && address !== initialContact?.address) {
        try {
          const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(address)}`);
          const data = await res.json();
          if (data && data.length > 0) {
            addressLat = parseFloat(data[0].lat);
            addressLng = parseFloat(data[0].lon);
          }
        } catch (err) {
          console.error('Failed to geocode address:', err);
        }
      } else if (address === initialContact?.address) {
        addressLat = initialContact?.addressLat;
        addressLng = initialContact?.addressLng;
      }

      await onAdd({
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        tags: tagsList,
        locationMet: location,
        dateMet: new Date(date).toISOString(),
        connections: selectedConnections,
        lastInteraction: new Date().toISOString(),
        lat: lat || 0,
        lng: lng || 0,
        birthday: birthday ? new Date(birthday).toISOString() : '',
        email: email || '',
        address: address || '',
        addressLat: addressLat ?? null,
        addressLng: addressLng ?? null,
        workplace: workplace || '',
      } as any);
      
      // Reset form
      setFirstName('');
      setLastName('');
      setTagInput('');
      setTagsList([]);
      setLocation('');
      setLat(undefined);
      setLng(undefined);
      setDate(new Date().toISOString().split('T')[0]);
      setBirthday('');
      setEmail('');
      setAddress('');
      setWorkplace('');
      setSelectedConnections([]);
      setConnectionSearch('');
      onClose();
    } catch (error) {
      console.error('Failed to add contact:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const toggleConnection = (id: string) => {
    setSelectedConnections(prev => 
      prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
    );
  };

  const filteredContacts = existingContacts.filter(c =>
    getFullName(c).toLowerCase().includes(connectionSearch.toLowerCase()) &&
    (!initialContact || c.id !== initialContact.id)
  );

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.9, opacity: 0 }}
            className="bg-[#1a1a1a] border border-[#333] rounded-2xl shadow-2xl w-full max-w-md overflow-hidden flex flex-col max-h-[90vh]"
          >
            <div className="flex justify-between items-center p-6 border-b border-[#333] shrink-0">
              <h2 className="text-xl font-bold text-white">{initialContact ? 'Edit Contact' : 'Add New Contact'}</h2>
              <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors" type="button">
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="flex flex-col overflow-hidden">
              <div className="p-6 space-y-4 overflow-y-auto">
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                      <User size={14} /> First Name
                    </label>
                    <input
                      required
                      value={firstName}
                      onChange={(e) => setFirstName(e.target.value)}
                      className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg py-2 px-3 text-sm focus:outline-none focus:border-indigo-500 transition-all"
                      placeholder="e.g. John"
                    />
                  </div>
                  <div className="space-y-1">
                    <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                      Last Name
                    </label>
                    <input
                      value={lastName}
                      onChange={(e) => setLastName(e.target.value)}
                      className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg py-2 px-3 text-sm focus:outline-none focus:border-indigo-500 transition-all"
                      placeholder="e.g. Doe"
                    />
                  </div>
                </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                  <Tag size={14} /> Tags
                </label>
                <div className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg p-2 flex flex-wrap gap-2 min-h-[42px] focus-within:border-indigo-500 transition-all">
                  {tagsList.map(tag => (
                    <span 
                      key={tag} 
                      className={`px-2 py-0.5 rounded border text-[10px] font-medium flex items-center gap-1 ${getTagColor(tag)}`}
                    >
                      {tag}
                      <button type="button" onClick={() => removeTag(tag)} className="hover:text-white">
                        <X size={10} />
                      </button>
                    </span>
                  ))}
                  <input
                    value={tagInput}
                    onChange={(e) => setTagInput(e.target.value)}
                    onKeyDown={handleTagKeyDown}
                    className="flex-1 bg-transparent border-none py-0 px-1 text-sm focus:outline-none min-w-[60px]"
                    placeholder={tagsList.length === 0 ? "Press Enter or comma to add tags" : ""}
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                    <MapPin size={14} /> Location
                  </label>
                  <div className="relative">
                    <input
                      required
                      value={location}
                      onChange={(e) => {
                        setLocation(e.target.value);
                        setShowLocationSuggestions(true);
                      }}
                      onFocus={() => setShowLocationSuggestions(true)}
                      onBlur={() => setTimeout(() => setShowLocationSuggestions(false), 200)}
                      className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg py-2 pl-3 pr-16 text-sm focus:outline-none focus:border-indigo-500 transition-all"
                      placeholder="City, Country"
                    />
                    <div className="absolute right-2 top-1/2 -translate-y-1/2 flex items-center gap-1">
                      <button
                        type="button"
                        onClick={handleLookupLocation}
                        disabled={isLookingUpLocation || !location}
                        className="text-gray-500 hover:text-indigo-400 transition-colors disabled:opacity-50 p-1"
                        title="Lookup address"
                      >
                        <Search size={14} className={isLookingUpLocation ? 'animate-pulse' : ''} />
                      </button>
                      <button
                        type="button"
                        onClick={handleUseGps}
                        disabled={isLocating}
                        className="text-gray-500 hover:text-indigo-400 transition-colors disabled:opacity-50 p-1"
                        title="Use current GPS location"
                      >
                        <Crosshair size={14} className={isLocating ? 'animate-spin' : ''} />
                      </button>
                    </div>
                    {showLocationSuggestions && locationSuggestions.length > 0 && (
                      <div className="absolute top-full left-0 w-full mt-1 bg-[#1a1a1a] border border-[#333] rounded-lg shadow-xl overflow-hidden z-[100]">
                        {locationSuggestions.map((s, i) => (
                          <div
                            key={i}
                            className="px-3 py-2 text-sm text-gray-300 hover:bg-[#333] hover:text-white cursor-pointer transition-colors truncate"
                            onClick={() => {
                              setLocation(s.display_name);
                              setLat(parseFloat(s.lat));
                              setLng(parseFloat(s.lon));
                              setShowLocationSuggestions(false);
                            }}
                          >
                            {s.display_name}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                  {lat !== undefined && lng !== undefined && (
                    <div className="h-24 w-full rounded-lg overflow-hidden border border-[#333] mt-2 relative z-0">
                      <MapContainer 
                        center={[lat, lng]} 
                        zoom={13} 
                        style={{ height: '100%', width: '100%' }}
                        zoomControl={false}
                      >
                        <TileLayer
                          url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a>'
                        />
                        <Marker position={[lat, lng]} icon={contactIcon} />
                        <MapEvents setLat={setLat} setLng={setLng} setLocation={setLocation} />
                        <MapUpdater lat={lat} lng={lng} />
                      </MapContainer>
                    </div>
                  )}
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                    <Calendar size={14} /> Date Met
                  </label>
                  <input
                    type="date"
                    required
                    value={date}
                    onChange={(e) => setDate(e.target.value)}
                    className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg py-2 px-3 text-sm focus:outline-none focus:border-indigo-500 transition-all h-[38px]"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                    <Calendar size={14} /> Birthday
                  </label>
                  <input
                    type="date"
                    value={birthday}
                    onChange={(e) => setBirthday(e.target.value)}
                    className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg py-2 px-3 text-sm focus:outline-none focus:border-indigo-500 transition-all h-[38px]"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                    <User size={14} /> Email
                  </label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg py-2 px-3 text-sm focus:outline-none focus:border-indigo-500 transition-all h-[38px]"
                    placeholder="john@example.com"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                    <MapPin size={14} /> Address
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      value={address}
                      onChange={(e) => {
                        setAddress(e.target.value);
                        setShowAddressSuggestions(true);
                      }}
                      onFocus={() => setShowAddressSuggestions(true)}
                      onBlur={() => setTimeout(() => setShowAddressSuggestions(false), 200)}
                      className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg py-2 pl-3 pr-10 text-sm focus:outline-none focus:border-indigo-500 transition-all"
                      placeholder="123 Main St"
                    />
                    <div className="absolute right-2 top-1/2 -translate-y-1/2 flex items-center gap-1">
                      <button
                        type="button"
                        onClick={handleLookupAddress}
                        disabled={isLookingUpAddress || !address}
                        className="text-gray-500 hover:text-indigo-400 transition-colors disabled:opacity-50 p-1"
                        title="Lookup address"
                      >
                        <Search size={14} className={isLookingUpAddress ? 'animate-pulse' : ''} />
                      </button>
                    </div>
                    {showAddressSuggestions && addressSuggestions.length > 0 && (
                      <div className="absolute top-full left-0 w-full mt-1 bg-[#1a1a1a] border border-[#333] rounded-lg shadow-xl overflow-hidden z-[100]">
                        {addressSuggestions.map((s, i) => (
                          <div
                            key={i}
                            className="px-3 py-2 text-sm text-gray-300 hover:bg-[#333] hover:text-white cursor-pointer transition-colors truncate"
                            onClick={() => {
                              setAddress(s.display_name);
                              setAddressLat(parseFloat(s.lat));
                              setAddressLng(parseFloat(s.lon));
                              setShowAddressSuggestions(false);
                            }}
                          >
                            {s.display_name}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                  {addressLat !== undefined && addressLng !== undefined && (
                    <div className="h-24 w-full rounded-lg overflow-hidden border border-[#333] mt-2 relative z-0">
                      <MapContainer 
                        center={[addressLat, addressLng]} 
                        zoom={13} 
                        style={{ height: '100%', width: '100%' }}
                        zoomControl={false}
                      >
                        <TileLayer
                          url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a>'
                        />
                        <Marker position={[addressLat, addressLng]} icon={houseIcon} />
                        <MapEvents setLat={setAddressLat} setLng={setAddressLng} setLocation={setAddress} />
                        <MapUpdater lat={addressLat} lng={addressLng} />
                      </MapContainer>
                    </div>
                  )}
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                    <User size={14} /> Workplace
                  </label>
                  <input
                    type="text"
                    value={workplace}
                    onChange={(e) => setWorkplace(e.target.value)}
                    className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg py-2 px-3 text-sm focus:outline-none focus:border-indigo-500 transition-all"
                    placeholder="Company Inc."
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                  <LinkIcon size={14} /> Connections
                </label>
                
                <div className="relative">
                  <Search className="absolute left-2 top-1/2 -translate-y-1/2 text-gray-600" size={12} />
                  <input
                    value={connectionSearch}
                    onChange={(e) => setConnectionSearch(e.target.value)}
                    className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg py-1.5 pl-7 pr-3 text-xs focus:outline-none focus:border-indigo-500 transition-all"
                    placeholder="Search contacts..."
                  />
                </div>

                <div className="max-h-32 overflow-y-auto bg-[#0a0a0a] border border-[#333] rounded-lg p-2 space-y-1">
                  {filteredContacts.map(c => (
                    <button
                      key={c.id}
                      type="button"
                      onClick={() => toggleConnection(c.id)}
                      className={`w-full text-left px-2 py-1 rounded text-xs transition-colors flex justify-between items-center ${
                        selectedConnections.includes(c.id) 
                          ? 'bg-indigo-500/20 text-indigo-400' 
                          : 'text-gray-400 hover:bg-[#1a1a1a]'
                      }`}
                    >
                      {getFullName(c)}
                      {selectedConnections.includes(c.id) && <div className="w-1.5 h-1.5 rounded-full bg-indigo-500" />}
                    </button>
                  ))}
                  {filteredContacts.length === 0 && (
                    <div className="text-center py-2 text-gray-600 text-xs italic">
                      {connectionSearch ? "No matches found" : "No contacts yet"}
                    </div>
                  )}
                </div>
              </div>
              </div>

              <div className="p-6 border-t border-[#333] shrink-0">
                <button
                  disabled={isSubmitting}
                  type="submit"
                  className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2 rounded-lg transition-all shadow-lg shadow-indigo-500/20 disabled:opacity-50"
                >
                  {isSubmitting ? (initialContact ? 'Saving...' : 'Adding...') : (initialContact ? 'Save Changes' : 'Add Contact')}
                </button>
              </div>
            </form>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};

export default AddContactModal;

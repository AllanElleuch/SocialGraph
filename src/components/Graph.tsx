import React, { useEffect, useRef } from 'react';
import * as d3 from 'd3';
import * as topojson from 'topojson-client';
import { Contact, GraphNode, GraphLink, PivotType } from '../types';

interface GraphProps {
  contacts: Contact[];
  pivot: PivotType;
  onSelectContact: (contact: Contact) => void;
}

const Graph: React.FC<GraphProps> = ({ contacts, pivot, onSelectContact }) => {
  const svgRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (!svgRef.current || contacts.length === 0) return;

    const width = svgRef.current.clientWidth;
    const height = svgRef.current.clientHeight;

    const svg = d3.select(svgRef.current);
    svg.selectAll('*').remove();

    // Add Definitions for Gradients and Filters
    const defs = svg.append('defs');

    // Background Radial Gradient
    const bgGradient = defs.append('radialGradient')
      .attr('id', 'bg-gradient')
      .attr('cx', '50%')
      .attr('cy', '50%')
      .attr('r', '70%');
    
    bgGradient.append('stop')
      .attr('offset', '0%')
      .attr('stop-color', '#1e293b');
    
    bgGradient.append('stop')
      .attr('offset', '100%')
      .attr('stop-color', '#020617');

    svg.append('rect')
      .attr('width', '100%')
      .attr('height', '100%')
      .attr('fill', 'url(#bg-gradient)');

    // Node Glow Filter
    const filter = defs.append('filter')
      .attr('id', 'glow')
      .attr('x', '-50%')
      .attr('y', '-50%')
      .attr('width', '200%')
      .attr('height', '200%');

    filter.append('feGaussianBlur')
      .attr('stdDeviation', '4')
      .attr('result', 'blur');

    filter.append('feComposite')
      .attr('in', 'SourceGraphic')
      .attr('in2', 'blur')
      .attr('operator', 'over');

    const g = svg.append('g');

    const zoom = d3.zoom<SVGSVGElement, unknown>()
      .scaleExtent([0.1, 8])
      .on('zoom', (event) => {
        g.attr('transform', event.transform);
      });

    svg.call(zoom);

    // Timeline Gradient Scale - Using Magma for better dark mode visibility
    const timeScale = d3.scaleSequential(d3.interpolateMagma)
      .domain([
        d3.min(contacts, (c: Contact) => new Date(c.dateMet).getTime()) || 0,
        d3.max(contacts, (c: Contact) => new Date(c.dateMet).getTime()) || Date.now()
      ]);

    if (pivot === 'location') {
      // Draw Map
      const projection = d3.geoMercator()
        .scale(width / 2 / Math.PI)
        .translate([width / 2, height / 2]);

      const path = d3.geoPath().projection(projection);

      // Fetch world map data
      d3.json('https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json').then((worldData: any) => {
        const countries = topojson.feature(worldData, worldData.objects.countries) as any;

        g.append('g')
          .selectAll('path')
          .data(countries.features)
          .join('path')
          .attr('d', path as any)
          .attr('fill', '#1a1a1a')
          .attr('stroke', '#333')
          .attr('stroke-width', 0.5);

        // Place contacts on map
        const nodes = g.append('g')
          .selectAll('g')
          .data(contacts)
          .join('g')
          .attr('transform', (d: Contact) => {
            const coords = projection([d.lng || 0, d.lat || 0]);
            return coords ? `translate(${coords[0]},${coords[1]})` : 'translate(0,0)';
          })
          .attr('cursor', 'pointer')
          .on('click', (event, d: Contact) => onSelectContact(d));

        nodes.append('circle')
          .attr('r', 6)
          .attr('fill', '#6366f1')
          .attr('stroke', '#fff')
          .attr('stroke-width', 1)
          .attr('class', 'animate-pulse');

        nodes.append('text')
          .text((d: Contact) => d.name)
          .attr('x', 10)
          .attr('y', 4)
          .attr('fill', '#94a3b8')
          .style('font-size', '10px')
          .style('font-family', 'Inter, sans-serif');
      });

      return;
    }

    // Graph Logic for Mutual and Timeline
    const nodes: GraphNode[] = contacts.map(c => ({
      id: c.id,
      name: c.name,
      type: 'contact',
      data: c
    }));

    const links: GraphLink[] = [];

    if (pivot === 'mutual') {
      contacts.forEach(c => {
        c.connections.forEach(connId => {
          if (c.id < connId) {
            links.push({ source: c.id, target: connId, type: 'connection' });
          }
        });
      });
    } else if (pivot === 'time') {
      const sorted = [...contacts].sort((a, b) => new Date(a.dateMet).getTime() - new Date(b.dateMet).getTime());
      for (let i = 0; i < sorted.length - 1; i++) {
        links.push({ source: sorted[i].id, target: sorted[i+1].id, type: 'time' });
      }
    }

    const simulation = d3.forceSimulation<GraphNode>(nodes)
      .force('link', d3.forceLink<GraphNode, GraphLink>(links).id(d => d.id).distance(150))
      .force('charge', d3.forceManyBody().strength(-400))
      .force('center', d3.forceCenter(width / 2, height / 2))
      .force('collision', d3.forceCollide().radius(60));

    const link = g.append('g')
      .attr('stroke', '#444')
      .attr('stroke-opacity', 0.4)
      .selectAll('line')
      .data(links)
      .join('line')
      .attr('stroke-width', 1)
      .attr('stroke-dasharray', d => d.type === 'time' ? '4,4' : null);

    const node = g.append('g')
      .selectAll('g')
      .data(nodes)
      .join('g')
      .attr('cursor', 'pointer')
      .on('click', (event, d) => onSelectContact(d.data))
      .call(d3.drag<SVGGElement, GraphNode>()
        .on('start', dragstarted)
        .on('drag', dragged)
        .on('end', dragended) as any);

    node.append('circle')
      .attr('r', 14)
      .attr('fill', d => {
        if (pivot === 'time') {
          return timeScale(new Date(d.data.dateMet).getTime());
        }
        return '#6366f1';
      })
      .attr('stroke', '#fff')
      .attr('stroke-width', 2)
      .style('filter', 'url(#glow)');

    node.append('text')
      .text(d => d.name)
      .attr('x', 18)
      .attr('y', 5)
      .attr('fill', '#e2e8f0')
      .style('font-size', '12px')
      .style('font-family', 'Inter, sans-serif');

    simulation.on('tick', () => {
      link
        .attr('x1', d => (d.source as any).x)
        .attr('y1', d => (d.source as any).y)
        .attr('x2', d => (d.target as any).x)
        .attr('y2', d => (d.target as any).y);

      node
        .attr('transform', d => `translate(${d.x},${d.y})`);
    });

    function dragstarted(event: any) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      event.subject.fx = event.subject.x;
      event.subject.fy = event.subject.y;
    }

    function dragged(event: any) {
      event.subject.fx = event.x;
      event.subject.fy = event.y;
    }

    function dragended(event: any) {
      if (!event.active) simulation.alphaTarget(0);
      event.subject.fx = null;
      event.subject.fy = null;
    }

    return () => simulation.stop();
  }, [contacts, pivot, onSelectContact]);

  return (
    <svg 
      ref={svgRef} 
      className="w-full h-full bg-[#0a0a0a]"
      style={{ touchAction: 'none' }}
    />
  );
};

export default Graph;

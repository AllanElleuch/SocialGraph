import React, { useEffect, useRef } from 'react';
import * as d3 from 'd3';
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

    let timePositionScale: d3.ScaleTime<number, number, never>;
    let xAxisGroup: d3.Selection<SVGGElement, unknown, null, undefined>;
    let axis: d3.Axis<Date | d3.NumberValue>;
    let simulation: d3.Simulation<GraphNode, undefined>;

    const zoom = d3.zoom<SVGSVGElement, unknown>()
      .scaleExtent([0.1, 100])
      .on('zoom', (event) => {
        if (pivot === 'time' && timePositionScale && xAxisGroup && simulation) {
          const transform = event.transform;
          const xTransform = d3.zoomIdentity.translate(transform.x, 0).scale(transform.k);
          const newScale = xTransform.rescaleX(timePositionScale);
          
          axis.scale(newScale);
          xAxisGroup.call(axis);
          xAxisGroup.selectAll('text')
            .attr('fill', '#94a3b8')
            .style('font-size', '12px')
            .style('font-family', 'Inter, sans-serif');
          xAxisGroup.selectAll('.time-axis path, .time-axis line').attr('stroke', '#475569');

          simulation.force('x', d3.forceX<GraphNode>(d => newScale(new Date(d.data.dateMet))).strength(1));
          simulation.alpha(0.3).restart();
        } else {
          g.attr('transform', event.transform);
        }
      });

    svg.call(zoom);

    // Timeline Gradient Scale - Using Magma for better dark mode visibility
    const timeScale = d3.scaleSequential(d3.interpolateMagma)
      .domain([
        d3.min(contacts, (c: Contact) => new Date(c.dateMet).getTime()) || 0,
        d3.max(contacts, (c: Contact) => new Date(c.dateMet).getTime()) || Date.now()
      ]);

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

    if (pivot === 'mutual') {
      simulation = d3.forceSimulation<GraphNode>(nodes)
        .force('link', d3.forceLink<GraphNode, GraphLink>(links).id(d => d.id).distance(150))
        .force('charge', d3.forceManyBody().strength(-400))
        .force('center', d3.forceCenter(width / 2, height / 2))
        .force('collision', d3.forceCollide().radius(60));
    } else if (pivot === 'time') {
      const minDate = d3.min(contacts, (c: Contact) => new Date(c.dateMet)) || new Date();
      const maxDate = d3.max(contacts, (c: Contact) => new Date(c.dateMet)) || new Date();
      
      if (minDate.getTime() === maxDate.getTime()) {
        minDate.setMonth(minDate.getMonth() - 1);
        maxDate.setMonth(maxDate.getMonth() + 1);
      }

      timePositionScale = d3.scaleTime()
        .domain([minDate, maxDate])
        .range([100, width - 100]);

      axis = d3.axisBottom(timePositionScale).ticks(width > 600 ? 10 : 5);
      xAxisGroup = g.append('g')
        .attr('transform', `translate(0, ${height / 2 + 100})`)
        .attr('class', 'time-axis')
        .call(axis);
        
      xAxisGroup.selectAll('text')
        .attr('fill', '#94a3b8')
        .style('font-size', '12px')
        .style('font-family', 'Inter, sans-serif');
      
      xAxisGroup.selectAll('.time-axis path, .time-axis line').attr('stroke', '#475569');

      simulation = d3.forceSimulation<GraphNode>(nodes)
        .force('link', d3.forceLink<GraphNode, GraphLink>(links).id(d => d.id).strength(0))
        .force('x', d3.forceX<GraphNode>(d => timePositionScale(new Date(d.data.dateMet))).strength(1))
        .force('y', d3.forceY<GraphNode>(height / 2).strength(0.05))
        .force('collision', d3.forceCollide().radius(40));
    }

    const link = g.append('g')
      .attr('stroke', '#444')
      .attr('stroke-opacity', 0.4)
      .selectAll('line')
      .data(links)
      .join('line')
      .attr('stroke-width', 1)
      .attr('stroke-dasharray', d => d.type === 'time' ? '4,4' : null);

    const linkText = g.append('g')
      .attr('class', 'link-labels')
      .selectAll('text')
      .data(links)
      .join('text')
      .attr('fill', '#64748b')
      .attr('font-size', '9px')
      .attr('text-anchor', 'middle')
      .attr('dy', -4)
      .style('pointer-events', 'none')
      .style('font-family', 'Inter, sans-serif')
      .text(d => d.type === 'time' ? 'Met after' : 'Connected');

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

      linkText
        .attr('x', d => ((d.source as any).x + (d.target as any).x) / 2)
        .attr('y', d => ((d.source as any).y + (d.target as any).y) / 2)
        .attr('transform', d => {
          const x1 = (d.source as any).x;
          const y1 = (d.source as any).y;
          const x2 = (d.target as any).x;
          const y2 = (d.target as any).y;
          const cx = (x1 + x2) / 2;
          const cy = (y1 + y2) / 2;
          let angle = Math.atan2(y2 - y1, x2 - x1) * 180 / Math.PI;
          if (angle > 90 || angle < -90) {
            angle += 180;
          }
          return `rotate(${angle}, ${cx}, ${cy})`;
        });

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
    <div className="relative w-full h-full">
      <svg 
        ref={svgRef} 
        className="w-full h-full bg-[#0a0a0a]"
        style={{ touchAction: 'none' }}
      />
    </div>
  );
};

export default Graph;

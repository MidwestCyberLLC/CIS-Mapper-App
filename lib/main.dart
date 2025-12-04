import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// --- Constants ---
class ApiUrls {
  static const String safeguards = 'https://raw.githubusercontent.com/MidwestCyberLLC/CIS-Tool-Mapping/refs/heads/main/safeguards.json';
  static const String tools = 'https://raw.githubusercontent.com/MidwestCyberLLC/CIS-Tool-Mapping/refs/heads/main/tools.json';
  static const String mapping = 'https://raw.githubusercontent.com/MidwestCyberLLC/CIS-Tool-Mapping/refs/heads/main/mapping.json';
}

// --- Models ---
class CISData {
  final List<Tool> tools;
  final List<Safeguard> safeguards;
  final List<Mapping> mappings;
  
  // Processed Maps
  final Map<String, Tool> toolMap;
  final Map<String, Safeguard> safeguardMap;
  final Map<String, List<String>> toolToSafeguards;

  CISData({
    required this.tools,
    required this.safeguards,
    required this.mappings,
    required this.toolMap,
    required this.safeguardMap,
    required this.toolToSafeguards,
  });
}

class Tool {
  final String id;
  final String name;
  final String description;
  final bool educationUse;
  final String cost;

  Tool({required this.id, required this.name, required this.description, required this.educationUse, required this.cost});

  factory Tool.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['ID'] ?? json['ToolID'] ?? '';
    return Tool(
      id: id.toString(),
      name: json['name'] ?? json['Name'] ?? json['ToolName'] ?? 'Unknown Tool',
      description: json['description'] ?? json['Description'] ?? '',
      educationUse: (json['EducationUse'] == true || json['EducationUse'] == 'true'),
      cost: json['Cost']?.toString() ?? '',
    );
  }
}

class Safeguard {
  final String id;
  final String title;
  final String description;
  final String tier;
  final String ig;
  final int controlNumber;

  Safeguard({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.ig,
    required this.controlNumber,
  });

  factory Safeguard.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['ID'] ?? json['SafeguardID'] ?? json['number'] ?? '';
    // Determine IG (simple fallback logic based on original code)
    String igVal = '3';
    if (json['IGNumber'] != null) {
      igVal = json['IGNumber'].toString();
    } else if (json['ig1'] == true) {
      igVal = '1';
    } else if (json['ig2'] == true) {
      igVal = '2';
    }

    return Safeguard(
      id: id.toString(),
      title: json['title'] ?? json['Title'] ?? json['name'] ?? '',
      description: json['description'] ?? json['Description'] ?? '',
      tier: (json['TierNumber'] ?? json['tier'] ?? json['Tier'] ?? 'N/A').toString(),
      ig: igVal,
      controlNumber: int.tryParse(json['ControlNumber']?.toString() ?? '0') ?? 0,
    );
  }
}

class Mapping {
  final String toolId;
  final String safeguardId;
  final String rationale;

  Mapping({required this.toolId, required this.safeguardId, required this.rationale});

  factory Mapping.fromJson(Map<String, dynamic> json) {
    return Mapping(
      toolId: (json['tool_id'] ?? json['ToolID'] ?? json['toolId'] ?? '').toString(),
      safeguardId: (json['safeguard_id'] ?? json['SafeguardID'] ?? json['safeguardId'] ?? '').toString(),
      rationale: json['Rationale'] ?? '',
    );
  }
}

// --- Main App ---

void main() {
  runApp(const CISMapperApp());
}

class CISMapperApp extends StatelessWidget {
  const CISMapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIS Mapper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A), // Slate 900
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CISData? _data;
  bool _loading = true;
  String _loadingStatus = "Connecting to Server...";
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Show disclaimer after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimer();
    });
  }

  Future<void> _fetchData() async {
    try {
      setState(() => _loadingStatus = "Fetching Safeguards...");
      final sgRes = await http.get(Uri.parse(ApiUrls.safeguards));
      
      setState(() => _loadingStatus = "Fetching Tools...");
      final tRes = await http.get(Uri.parse(ApiUrls.tools));
      
      setState(() => _loadingStatus = "Fetching Mappings...");
      final mRes = await http.get(Uri.parse(ApiUrls.mapping));

      if (sgRes.statusCode != 200 || tRes.statusCode != 200 || mRes.statusCode != 200) {
        throw Exception("Failed to load data from servers");
      }

      setState(() => _loadingStatus = "Processing Data...");

      final List<dynamic> sgJson = jsonDecode(sgRes.body);
      final List<dynamic> tJson = jsonDecode(tRes.body);
      final List<dynamic> mJson = jsonDecode(mRes.body);

      final tools = tJson.map((e) => Tool.fromJson(e)).toList();
      final safeguards = sgJson.map((e) => Safeguard.fromJson(e)).toList();
      final mappings = mJson.map((e) => Mapping.fromJson(e)).toList();

      // Create Lookups
      final toolMap = {for (var t in tools) t.id: t};
      final safeguardMap = {for (var s in safeguards) s.id: s};
      final toolToSafeguards = <String, List<String>>{};

      for (var t in tools) {
        toolToSafeguards[t.id] = [];
      }

      for (var m in mappings) {
        if (toolToSafeguards.containsKey(m.toolId)) {
          toolToSafeguards[m.toolId]!.add(m.safeguardId);
        }
      }

      setState(() {
        _data = CISData(
          tools: tools,
          safeguards: safeguards,
          mappings: mappings,
          toolMap: toolMap,
          safeguardMap: safeguardMap,
          toolToSafeguards: toolToSafeguards,
        );
        _loading = false;
      });

    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("AI Analysis Disclaimer"),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "The tools and mappings listed in this app are the result of analysis by AI. It is your responsibility to determine if a tool successfully meets the needs of your organization.",
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text("CIS Mapper App", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_loadingStatus, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text("CIS Mapper", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDisclaimer,
          )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MapperView(data: _data!),
          AggregatorView(data: _data!),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Mapper"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Aggregator"),
        ],
      ),
    );
  }
}

// --- Mapper View ---

class MapperView extends StatefulWidget {
  final CISData data;
  const MapperView({super.key, required this.data});

  @override
  State<MapperView> createState() => _MapperViewState();
}

class _MapperViewState extends State<MapperView> {
  String _viewMode = 'control'; // 'control' | 'tool'
  String _search = '';
  bool _showFilters = false;
  
  // Filters
  List<String> _igFilter = [];
  List<String> _tierFilter = [];
  bool _eduFilter = false;
  List<String> _costFilter = [];

  List<dynamic> _getFilteredContent() {
    final term = _search.toLowerCase();
    
    if (_viewMode == 'control') {
      // Group by Control Number
      final controls = <int, List<Safeguard>>{};
      for (var sg in widget.data.safeguards) {
        if (!controls.containsKey(sg.controlNumber)) controls[sg.controlNumber] = [];
        controls[sg.controlNumber]!.add(sg);
      }

      List<Map<String, dynamic>> results = [];
      
      final sortedKeys = controls.keys.toList()..sort();

      for (var cNum in sortedKeys) {
        final sgs = controls[cNum]!;
        final visibleSgs = sgs.where((sg) {
          final textMatch = term.isEmpty || 
            sg.title.toLowerCase().contains(term) || 
            sg.description.toLowerCase().contains(term) ||
            sg.id.toLowerCase().contains(term);
          
          final igMatch = _igFilter.isEmpty || _igFilter.contains(sg.ig);
          final tierMatch = _tierFilter.isEmpty || _tierFilter.contains(sg.tier);
          
          return textMatch && igMatch && tierMatch;
        }).toList();

        if (visibleSgs.isNotEmpty) {
          results.add({'id': cNum, 'items': visibleSgs});
        }
      }
      return results;
    } else {
      // Tools
      return widget.data.tools.where((tool) {
         final textMatch = term.isEmpty || 
            tool.name.toLowerCase().contains(term) || 
            tool.description.toLowerCase().contains(term);
        
        final eduMatch = !_eduFilter || tool.educationUse;
        
        final toolCosts = tool.cost.split(',').map((c) => c.trim()).toList();
        final costMatch = _costFilter.isEmpty || toolCosts.any((c) => _costFilter.contains(c));

        return textMatch && eduMatch && costMatch;
      }).toList()..sort((a,b) => a.name.compareTo(b.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _getFilteredContent();

    return Column(
      children: [
        // Controls Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildToggleBtn('By Control', 'control')),
                    Expanded(child: _buildToggleBtn('By Tool', 'tool')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Search
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _search = val),
                      decoration: InputDecoration(
                        hintText: _viewMode == 'control' ? "Search Safeguards..." : "Search Tools...",
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        fillColor: Colors.grey[50],
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                    icon: Icon(Icons.filter_list, color: _showFilters ? Colors.blue : Colors.grey),
                  )
                ],
              ),
              // Filters
              if (_showFilters) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!)
                  ),
                  child: _viewMode == 'control' 
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterSection("Implementation Group", ['1', '2', '3'], _igFilter, (l) => setState(() => _igFilter = l)),
                          const SizedBox(height: 8),
                          _buildFilterSection("Tier", ['1', '2', '3', '4', '5', '6'], _tierFilter, (l) => setState(() => _tierFilter = l)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                             FilterChip(
                               label: const Text("K-12 Education Use", style: TextStyle(fontSize: 11)),
                               selected: _eduFilter,
                               onSelected: (v) => setState(() => _eduFilter = v),
                             )
                          ]),
                          const SizedBox(height: 8),
                          _buildFilterSection("Cost", ['\$', '\$\$', '\$\$\$', '\$\$\$\$'], _costFilter, (l) => setState(() => _costFilter = l)),
                        ],
                      )
                )
              ]
            ],
          ),
        ),
        
        // List Content
        Expanded(
          child: content.isEmpty 
            ? const Center(child: Text("No results found", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: content.length,
                padding: const EdgeInsets.only(bottom: 80),
                itemBuilder: (ctx, i) {
                  if (_viewMode == 'control') {
                    final group = content[i] as Map<String, dynamic>;
                    return ControlCard(
                      controlId: group['id'], 
                      items: group['items'], 
                      data: widget.data
                    );
                  } else {
                    final tool = content[i] as Tool;
                    return ToolCard(tool: tool, data: widget.data);
                  }
                },
              ),
        ),
      ],
    );
  }

  Widget _buildToggleBtn(String label, String value) {
    final isSelected = _viewMode == value;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? Colors.blue[800] : Colors.grey[600]
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, List<String> current, Function(List<String>) onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        Wrap(
          spacing: 6,
          children: options.map((opt) {
            final selected = current.contains(opt);
            return FilterChip(
              label: Text(opt, style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.black87)),
              selected: selected,
              onSelected: (val) {
                final newList = List<String>.from(current);
                if (val) newList.add(opt); else newList.remove(opt);
                onChange(newList);
              },
              selectedColor: Colors.blue[600],
              checkmarkColor: Colors.white,
              padding: const EdgeInsets.all(0),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        )
      ],
    );
  }
}

// --- Widgets for Mapper ---

class ControlCard extends StatelessWidget {
  final int controlId;
  final List<Safeguard> items;
  final CISData data;

  const ControlCard({super.key, required this.controlId, required this.items, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: ExpansionTile(
        title: Text("CIS Control $controlId", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${items.length} Safeguards", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        shape: const Border(),
        children: items.map((sg) => SafeguardItem(sg: sg, data: data)).toList(),
      ),
    );
  }
}

class SafeguardItem extends StatefulWidget {
  final Safeguard sg;
  final CISData data;
  const SafeguardItem({super.key, required this.sg, required this.data});

  @override
  State<SafeguardItem> createState() => _SafeguardItemState();
}

class _SafeguardItemState extends State<SafeguardItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Find related tools
    final relatedTools = widget.data.mappings
        .where((m) => m.safeguardId == widget.sg.id)
        .map((m) {
           final tool = widget.data.toolMap[m.toolId];
           return tool != null ? {'tool': tool, 'rationale': m.rationale} : null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!))
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            title: Row(
              children: [
                Expanded(child: Text("${widget.sg.id} - ${widget.sg.title}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                _Badge(text: "IG${widget.sg.ig}", color: Colors.grey[200]!, textColor: Colors.black87),
                const SizedBox(width: 4),
                _Badge(text: "T${widget.sg.tier}", color: Colors.blue[100]!, textColor: Colors.blue[900]!),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(widget.sg.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Text("${relatedTools.length} Mapped Tools", style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
          ),
          if (_expanded)
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: relatedTools.isEmpty 
                  ? [const Padding(padding: EdgeInsets.all(8), child: Text("No tools mapped yet.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))]
                  : relatedTools.map((item) {
                      final Tool tool = item['tool'];
                      final String rationale = item['rationale'];
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(6)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(tool.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                if (tool.cost.isNotEmpty) _Badge(text: tool.cost, color: Colors.green[100]!, textColor: Colors.green[900]!),
                              ],
                            ),
                            if (rationale.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('"$rationale"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.grey)),
                            ]
                          ],
                        ),
                      );
                  }).toList(),
              ),
            )
        ],
      ),
    );
  }
}

class ToolCard extends StatefulWidget {
  final Tool tool;
  final CISData data;
  const ToolCard({super.key, required this.tool, required this.data});

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final relatedSgs = widget.data.mappings
        .where((m) => m.toolId == widget.tool.id)
        .map((m) {
           final sg = widget.data.safeguardMap[m.safeguardId];
           return sg != null ? {'sg': sg, 'rationale': m.rationale} : null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(widget.tool.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      if (widget.tool.educationUse) _Badge(text: "K-12", color: Colors.purple[100]!, textColor: Colors.purple[900]!),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(widget.tool.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text("${relatedSgs.length} Safeguards Covered", style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.bold)),
                       Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey),
                    ],
                  )
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!))
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: relatedSgs.map((item) {
                  final Safeguard sg = item['sg'];
                  final String rationale = item['rationale'];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!))
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           children: [
                             Text(sg.id, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[700])),
                             const Spacer(),
                             Text("IG${sg.ig}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                           ],
                         ),
                         const SizedBox(height: 2),
                         Text(sg.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                         if (rationale.isNotEmpty) 
                           Padding(
                             padding: const EdgeInsets.only(left: 6, top: 4),
                             child: Container(
                               decoration: BoxDecoration(
                                 border: Border(left: BorderSide(color: Colors.grey[300]!, width: 2))
                               ),
                               padding: const EdgeInsets.only(left: 8),
                               child: Text(rationale, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.grey)),
                             ),
                           )
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
        ],
      ),
    );
  }
}

// --- Aggregator View ---

class AggregatorView extends StatefulWidget {
  final CISData data;
  const AggregatorView({super.key, required this.data});

  @override
  State<AggregatorView> createState() => _AggregatorViewState();
}

class _AggregatorViewState extends State<AggregatorView> {
  final Set<String> _selectedToolIds = {};
  bool _showToolSelector = true;
  String _toolSearch = '';

  // Simple heatmap filters logic could be added here similar to mapper

  Map<String, int> _calculateCoverage() {
    final counts = <String, int>{};
    for (var tId in _selectedToolIds) {
      final sgs = widget.data.toolToSafeguards[tId] ?? [];
      for (var sgId in sgs) {
        counts[sgId] = (counts[sgId] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final coverage = _calculateCoverage();
    
    // Filter safeguards for grid
    final visibleSgs = widget.data.safeguards.toList();
    // Natural Sort by ID (Simple approximation)
    visibleSgs.sort((a, b) => a.id.compareTo(b.id));

    final availableTools = widget.data.tools
      .where((t) => !_selectedToolIds.contains(t.id) && t.name.toLowerCase().contains(_toolSearch.toLowerCase()))
      .toList();
    availableTools.sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        // Header Control
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Coverage Heatmap", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _showToolSelector = !_showToolSelector),
                    child: Text(_showToolSelector ? "Hide Tools" : "Select Tools", style: const TextStyle(fontSize: 12)),
                  )
                ],
              ),
              if (_showToolSelector) ...[
                const SizedBox(height: 12),
                // Selected Chips
                if (_selectedToolIds.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _selectedToolIds.map((id) {
                        final tool = widget.data.toolMap[id];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(tool?.name ?? id, style: const TextStyle(fontSize: 11)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(() => _selectedToolIds.remove(id)),
                            backgroundColor: Colors.blue[100],
                            padding: const EdgeInsets.all(0),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (_selectedToolIds.isEmpty)
                  const Align(alignment: Alignment.centerLeft, child: Text("No tools selected.", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))),
                
                const SizedBox(height: 8),
                // Autocomplete-like Search
                 TextField(
                    decoration: InputDecoration(
                      hintText: "Add tool...",
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      fillColor: Colors.grey[50],
                      filled: true,
                    ),
                    onChanged: (v) => setState(() => _toolSearch = v),
                 ),
                 if (_toolSearch.isNotEmpty)
                   Container(
                     constraints: const BoxConstraints(maxHeight: 150),
                     decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!)),
                     child: ListView.builder(
                       shrinkWrap: true,
                       itemCount: availableTools.length,
                       itemBuilder: (ctx, i) {
                         final t = availableTools[i];
                         return ListTile(
                           dense: true,
                           title: Text(t.name, style: const TextStyle(fontSize: 13)),
                           onTap: () {
                             setState(() {
                               _selectedToolIds.add(t.id);
                               _toolSearch = '';
                             });
                           },
                         );
                       },
                     ),
                   )
              ]
            ],
          ),
        ),

        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, // Adaptable based on screen width ideally
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: visibleSgs.length,
            itemBuilder: (ctx, i) {
              final sg = visibleSgs[i];
              final count = coverage[sg.id] ?? 0;
              return _HeatmapCell(sg: sg, count: count, data: widget.data, selectedTools: _selectedToolIds);
            },
          ),
        )
      ],
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  final Safeguard sg;
  final int count;
  final CISData data;
  final Set<String> selectedTools;

  const _HeatmapCell({required this.sg, required this.count, required this.data, required this.selectedTools});

  Color _getColor() {
    if (count == 0) return Colors.white;
    if (count == 1) return Colors.green[100]!;
    if (count == 2) return Colors.green[300]!;
    if (count == 3) return Colors.green[400]!;
    return Colors.green[700]!;
  }

  Color _getTextColor() {
    if (count >= 3) return Colors.white;
    return count == 0 ? Colors.grey[400]! : Colors.green[900]!;
  }

  @override
  Widget build(BuildContext context) {
    final simpleId = sg.id.replaceAll(RegExp(r'^SG\s?'), '');
    return InkWell(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: _getColor(),
          border: Border.all(color: count == 0 ? Colors.grey[200]! : Colors.green[200]!),
          borderRadius: BorderRadius.circular(4)
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(simpleId, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getTextColor())),
            if (count > 0) Text("x$count", style: TextStyle(fontSize: 10, color: _getTextColor().withOpacity(0.8)))
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    // Find tools contributing to this count
    final coveredBy = selectedTools.where((tId) {
      return data.toolToSafeguards[tId]?.contains(sg.id) ?? false;
    }).map((tId) => data.toolMap[tId]?.name ?? tId).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sg.id, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sg.title, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              const Divider(),
              Text("Covered By ($count)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              if (coveredBy.isEmpty)
                const Text("Missing Coverage", style: TextStyle(fontSize: 12, color: Colors.redAccent, fontStyle: FontStyle.italic))
              else
                ...coveredBy.map((name) => Row(
                  children: [
                    const Icon(Icons.check, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
                  ],
                )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))
        ],
      ),
    );
  }
}

// --- Common Helper ---
class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _Badge({required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold)),
    );
  }
}
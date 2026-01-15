import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/channel.dart';
import '../widgets/focusable_action_wrapper.dart';
import '../models/epg_program.dart';
import 'package:intl/intl.dart';

// Since I cannot modify the imports easily without seeing the top of the file,
// I will assume this class is being appended to content_list_screen.dart
// But wait, I should just append this class to the end of content_list_screen.dart using replace_file_content or a similar tool.
// Writing to a new file might be cleaner but requires fixing imports in content_list_screen.dart.
// Let's stick to appending it to content_list_screen.dart to avoid import hell,
// OR define it inline in _buildLiveLayout to avoid a new class if it's too complex.
// Actually, creating a separate file is better practice. Let's do that and add the import.

class CombinedLiveView extends StatelessWidget {
  final List<Channel> displayedContent;
  final bool isAndroidTV;
  final bool useStandardTextField;
  final String selectedCategory;
  final Widget Function() onHeaderBuild;
  final Function(Channel) onChannelTap;
  final FocusNode firstContentFocus;
  final Channel? previewChannel;
  final Player previewPlayer;
  final VideoController? previewController;
  final Function(Channel) onPreviewSelect;
  final List<EpgProgram> epgPrograms;

  const CombinedLiveView({
    super.key,
    required this.displayedContent,
    required this.isAndroidTV,
    required this.useStandardTextField,
    required this.selectedCategory,
    required this.onHeaderBuild,
    required this.onChannelTap,
    required this.firstContentFocus,
    required this.previewChannel,
    required this.previewPlayer,
    required this.previewController,
    required this.onPreviewSelect,
    required this.epgPrograms,
  });

  @override
  Widget build(BuildContext context) {
    // New Layout:
    // Column [ Header, Expanded(Row [ List, Preview ]) ]

    // Note: The Header implementation in the parent passed down via onHeaderBuild is just the widget.

    return Expanded(
      child: Container(
        color: const Color(0xFF151515), // Background for the whole right area
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header (Spans full width)
            onHeaderBuild(),

            // 2. Content Area (Split into List and Preview)
            Expanded(
              child: Row(
                children: [
                  // Channel List (Flex 4)
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white10),
                        ),
                      ),
                      child: displayedContent.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum canal',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: displayedContent.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Colors.white10,
                              ),
                              itemBuilder: (context, index) {
                                final channel = displayedContent[index];
                                final isPreviewing =
                                    previewChannel?.id == channel.id;

                                return FocusableActionWrapper(
                                  showFocusHighlight: isAndroidTV,
                                  focusNode: index == 0
                                      ? firstContentFocus
                                      : null,
                                  onTap: () {
                                    if (isPreviewing) {
                                      onChannelTap(channel);
                                    } else {
                                      onPreviewSelect(channel);
                                    }
                                  },
                                  child: Container(
                                    color: isPreviewing
                                        ? Colors.blue.withOpacity(0.2)
                                        : null,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child:
                                                (channel.logoUrl != null &&
                                                    channel.logoUrl!.isNotEmpty)
                                                ? Image.network(
                                                    channel.logoUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) => const Icon(
                                                          Icons.tv,
                                                          color: Colors.grey,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.tv,
                                                    color: Colors.grey,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            channel.name,
                                            style: TextStyle(
                                              color: isPreviewing
                                                  ? Colors.blue
                                                  : Colors.white,
                                              fontWeight: isPreviewing
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isPreviewing)
                                          const Icon(
                                            Icons.play_circle_fill,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),

                  // Preview Area (Flex 6)
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        // Video Preview
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            color: Colors.black,
                            child: previewChannel == null
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.tv,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Selecione um canal para visualizar",
                                          style: TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : previewController == null
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.blue,
                                    ),
                                  )
                                : Video(
                                    controller: previewController!,
                                    controls: NoVideoControls,
                                  ),
                          ),
                        ),
                        // EPG List (Scrollable)
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: const Color(0xFF0A0A0A),
                            child: previewChannel == null
                                ? const SizedBox.shrink()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              previewChannel!.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Categoria: ${previewChannel!.category}",
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              "Guia de Programação (EPG)",
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: epgPrograms.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  "Sem informações de programação.",
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              )
                                            : ListView.builder(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                itemCount: epgPrograms.length,
                                                itemBuilder: (context, index) {
                                                  final program =
                                                      epgPrograms[index];
                                                  final isLive =
                                                      program.isCurrent;
                                                  final dateFormat = DateFormat(
                                                    'HH:mm',
                                                  );

                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isLive
                                                          ? Colors.blue
                                                                .withOpacity(
                                                                  0.1,
                                                                )
                                                          : Colors.white
                                                                .withOpacity(
                                                                  0.05,
                                                                ),
                                                      border: isLive
                                                          ? Border.all(
                                                              color: Colors.blue
                                                                  .withOpacity(
                                                                    0.5,
                                                                  ),
                                                            )
                                                          : null,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                              "${dateFormat.format(program.start)} - ${dateFormat.format(program.end)}",
                                                              style: TextStyle(
                                                                color: isLive
                                                                    ? Colors
                                                                          .blueAccent
                                                                    : Colors
                                                                          .grey,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            if (isLive) ...[
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .red,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                                child: const Text(
                                                                  "AGORA",
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          program.title,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        if (program
                                                            .description
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            program.description,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[400],
                                                              fontSize: 12,
                                                            ),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

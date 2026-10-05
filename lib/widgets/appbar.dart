import 'package:bbc_api_tool/widgets/ramadan_color_pallete.dart';
import 'package:flutter/material.dart';

class RamadanAppBar extends StatefulWidget implements PreferredSizeWidget {
  final double height;

  const RamadanAppBar({
    super.key,
    this.height = 100, // default height
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  State<RamadanAppBar> createState() => _RamadanAppBarState();
}

class _RamadanAppBarState extends State<RamadanAppBar>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -0.2, end: 0.2)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    final double height = widget.preferredSize.height;
    final double fontSize = height * 0.45;
    final double lanternSize = height * 0.8;
    final double topPadding = height * 0.15;

    return PreferredSize(
      preferredSize: widget.preferredSize,
      child: Stack(
        children: [
          AppBar(
            toolbarHeight: height, // 👈 Important
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            title: Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                "رمضان كريم",
                style: TextStyle(
                  fontFamily: "Amiri",
                  fontSize: fontSize,
                  color: ramadanSoftGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ramadanGold, width: 2),
                  left: BorderSide(color: ramadanGold, width: 2),
                  right: BorderSide(color: ramadanGold, width: 2),
                ),
                image: DecorationImage(
                  image: AssetImage("assets/ramadan/appbar_bg.jpg"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Left Lantern
          Positioned(
            top: height * 0.1,
            left: height * 0.4,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animation.value,
                  child: child,
                );
              },
              child: Image.asset(
                "assets/ramadan/islamic-lantern-svgrepo-com (1).png",
                height: lanternSize,
              ),
            ),
          ),

          // Right Lantern
          Positioned(
            top: height * 0.1,
            right: height * 0.4,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_animation.value,
                  child: child,
                );
              },
              child: Image.asset(
                "assets/ramadan/islamic-lantern-svgrepo-com (1).png",
                height: lanternSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}